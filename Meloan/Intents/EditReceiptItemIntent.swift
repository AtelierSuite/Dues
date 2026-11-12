import AppIntents
import Foundation

struct EditReceiptItemIntent: AppIntent {

    static var title: LocalizedStringResource = "Edit Item"
    static var description = IntentDescription(
        "Changes an item's name, price or quantity, or who it's for. Leave anything you don't want to change empty.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Item")
    var item: ReceiptItemEntity

    @Parameter(title: "New Name")
    var newName: String?

    @Parameter(title: "New Price", description: "The total price for the item, for all of the quantity.")
    var newPrice: Double?

    @Parameter(title: "New Quantity", inclusiveRange: (1, 999))
    var newQuantity: Int?

    @Parameter(title: "For", description: "Who the item is for now.")
    var person: PersonEntity?

    @Parameter(title: "Share with Everyone", description: "Split the item between everyone on the receipt.",
               default: false)
    var shareWithEveryone: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Edit \(\.$item)") {
            \.$newName
            \.$newPrice
            \.$newQuantity
            \.$person
            \.$shareWithEveryone
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptItemEntity> & ProvidesDialog {
        let item = try IntentStore.item(self.item)
        guard let receipt = item.receipts?.first else { throw IntentError.itemNotOnReceipt }
        let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedName, trimmedName.isEmpty { throw IntentError.emptyName }
        if let newPrice, newPrice < 0 { throw IntentError.negativePrice }
        let person = try person.map { try IntentStore.person($0) }
        guard trimmedName != nil || newPrice != nil || newQuantity != nil || person != nil || shareWithEveryone else {
            throw IntentError.nothingToChange
        }

        if let trimmedName { item.name = trimmedName }
        if let newPrice { item.price = newPrice }
        if let newQuantity { item.amount = newQuantity }
        reassign(item, on: receipt, to: person)
        receipt.applyAutoCharges(in: IntentStore.context)
        try IntentStore.save()

        return .result(value: ReceiptItemEntity(from: item), dialog: "Updated \(item.name) on \(receipt.name).")
    }

    @MainActor
    private func reassign(_ item: ReceiptItem, on receipt: Receipt, to person: Person?) {
        if shareWithEveryone {
            receipt.reassign(item, to: nil, markSelfPaid: IntentStore.marksSelfPaid)
        } else if let person {
            // An item's owner has to be splitting the receipt for their share to count.
            if !receipt.contains(participant: person) {
                receipt.addPeopleWhoParticipated(from: [person])
                let participantIDs = Set(receipt.participants().map { $0.id })
                for sharedItem in receipt.receiptItems ?? [] where sharedItem.person == nil {
                    sharedItem.refreshSharedPaidState(participantIDs: participantIDs)
                }
            }
            receipt.reassign(item, to: person, markSelfPaid: IntentStore.marksSelfPaid)
        }
    }
}
