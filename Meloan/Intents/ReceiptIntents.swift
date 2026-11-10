import AppIntents
import Foundation
import SwiftData

struct CreateReceiptIntent: AppIntent {

    static var title: LocalizedStringResource = "Create Receipt"
    static var description = IntentDescription(
        "Creates a new receipt to split. Add items to it afterwards with Add Item to Receipt.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Name", requestValueDialog: "What should the receipt be called?")
    var name: String

    @Parameter(title: "Paid By", description: "The person who paid the bill.")
    var payer: PersonEntity?

    @Parameter(title: "Participants", description: "Everyone splitting the receipt, besides the person who paid.")
    var participants: [PersonEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary("Create a receipt named \(\.$name)") {
            \.$payer
            \.$participants
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw IntentError.emptyName }

        let receipt = Receipt(name: trimmedName)
        IntentStore.context.insert(receipt)
        let payer = try payer.map { try IntentStore.person($0) }
        receipt.setPersonWhoPaid(to: payer)
        var people = try IntentStore.people(participants ?? [])
        if let payer, !people.contains(where: { $0.id == payer.id }) {
            people.insert(payer, at: 0)
        }
        var seenIDs = Set<String>()
        receipt.addPeopleWhoParticipated(from: people.filter { seenIDs.insert($0.id).inserted })
        try IntentStore.save()

        return .result(value: ReceiptEntity(from: receipt),
                       dialog: "Created the receipt \(trimmedName).")
    }
}

struct AddReceiptItemIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Item to Receipt"
    static var description = IntentDescription(
        "Adds an item to a receipt, either for one person or shared by everyone on it.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    @Parameter(title: "Item Name", requestValueDialog: "What's the item called?")
    var name: String

    @Parameter(title: "Price", description: "The total price for the item, for all of the quantity.",
               requestValueDialog: "How much was it?")
    var price: Double

    @Parameter(title: "Quantity", default: 1, inclusiveRange: (1, 999))
    var quantity: Int

    @Parameter(title: "For", description: "Who the item is for. Leave empty to share it with everyone on the receipt.")
    var person: PersonEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name) for \(\.$price) to \(\.$receipt)") {
            \.$quantity
            \.$person
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptItemEntity> & ProvidesDialog {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw IntentError.emptyName }
        guard price >= 0 else { throw IntentError.negativePrice }

        let receipt = try IntentStore.receipt(self.receipt)
        let person = try person.map { try IntentStore.person($0) }
        // An item's owner has to be splitting the receipt for their share to count.
        if let person, !receipt.contains(participant: person) {
            receipt.addPeopleWhoParticipated(from: [person])
        }

        let item = ReceiptItem(name: trimmedName, price: price, amount: max(quantity, 1))
        IntentStore.context.insert(item)
        item.setPurchaser(to: person)
        receipt.addReceiptItems(from: [item])

        let participantIDs = Set(receipt.participants().map { $0.id })
        if IntentStore.marksSelfPaid, let payer = receipt.personWhoPaid {
            if let person {
                item.paid = person.id == payer.id
            } else {
                item.addPersonWhoPaid(from: [payer])
            }
        }
        // A new participant changes who still owes on every shared item.
        for sharedItem in receipt.receiptItems ?? [] where sharedItem.person == nil {
            sharedItem.refreshSharedPaidState(participantIDs: participantIDs)
        }
        try IntentStore.save()

        return .result(value: ReceiptItemEntity(from: item),
                       dialog: "Added \(trimmedName) to \(receipt.name).")
    }
}

struct MarkReceiptItemPaidIntent: AppIntent {

    static var title: LocalizedStringResource = "Mark Item as Paid"
    static var description = IntentDescription(
        "Marks an item on a receipt as paid or unpaid, for everyone or for one person's share.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Item")
    var item: ReceiptItemEntity

    @Parameter(title: "Status", default: true,
               displayName: Bool.IntentDisplayName(true: "paid", false: "unpaid"))
    var paid: Bool

    @Parameter(title: "Person", description: "Whose share of a shared item to settle. Leave empty to settle it for everyone.")
    var person: PersonEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$item) as \(\.$paid)") {
            \.$person
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptItemEntity> & ProvidesDialog {
        let item = try IntentStore.item(self.item)
        guard let receipt = item.receipts?.first else { throw IntentError.itemNotOnReceipt }
        let person = try person.map { try IntentStore.person($0) }
        if let person, item.person == nil, !receipt.contains(participant: person) {
            throw IntentError.personNotOnReceipt
        }
        receipt.setSettled(item, paid: paid, for: person)
        try IntentStore.save()

        let dialog: IntentDialog = paid ?
            "Marked \(item.name) as paid." : "Marked \(item.name) as unpaid."
        return .result(value: ReceiptItemEntity(from: item), dialog: dialog)
    }
}

struct MarkReceiptPaidIntent: AppIntent {

    static var title: LocalizedStringResource = "Mark Receipt as Paid"
    static var description = IntentDescription(
        "Marks every item on a receipt as paid or unpaid, or just the items one person owes.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    @Parameter(title: "Status", default: true,
               displayName: Bool.IntentDisplayName(true: "paid", false: "unpaid"))
    var paid: Bool

    @Parameter(title: "Person", description: "Settle only what this person owes. Leave empty to settle the whole receipt.")
    var person: PersonEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$receipt) as \(\.$paid)") {
            \.$person
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        let receipt = try IntentStore.receipt(self.receipt)
        let person = try person.map { try IntentStore.person($0) }
        if let person, !receipt.contains(participant: person) {
            throw IntentError.personNotOnReceipt
        }
        receipt.setSettled(paid: paid, for: person)
        try IntentStore.save()

        let dialog: IntentDialog
        switch (paid, person) {
        case (true, .some(let person)): dialog = "Marked \(person.name)'s items on \(receipt.name) as paid."
        case (false, .some(let person)): dialog = "Marked \(person.name)'s items on \(receipt.name) as unpaid."
        case (true, .none): dialog = "Marked \(receipt.name) as paid."
        case (false, .none): dialog = "Marked \(receipt.name) as unpaid."
        }
        return .result(value: ReceiptEntity(from: receipt), dialog: dialog)
    }
}

struct AddPersonIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Person"
    static var description = IntentDescription(
        "Adds a person to split receipts with.",
        categoryName: "People"
    )

    @Parameter(title: "Name", requestValueDialog: "What's their name?")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$name) to people")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PersonEntity> & ProvidesDialog {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw IntentError.emptyName }
        let person = Person(name: trimmedName)
        IntentStore.context.insert(person)
        try IntentStore.save()
        return .result(value: PersonEntity(from: person), dialog: "Added \(trimmedName).")
    }
}
