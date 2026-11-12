import AppIntents
import Foundation
import SwiftData

struct GetPersonIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Person"
    static var description = IntentDescription(
        "Gets a person and how much they owe you and you owe them.",
        categoryName: "People"
    )

    @Parameter(title: "Person")
    var person: PersonEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$person)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PersonEntity> & ProvidesDialog {
        let person = try IntentStore.person(self.person)
        let entity = PersonEntity.make(from: [person])[0]
        let owesYou = format(entity.owesYou)
        let youOwe = format(entity.youOwe)

        let dialog: IntentDialog
        switch (entity.isMe, entity.owesYou > 0, entity.youOwe > 0) {
        case (true, false, false): dialog = "Everyone's settled up with you."
        case (true, _, _): dialog = "People owe you \(owesYou) in total, and you owe \(youOwe)."
        case (false, false, false): dialog = "You and \(entity.name) are settled up."
        case (false, true, false): dialog = "\(entity.name) owes you \(owesYou)."
        case (false, false, true): dialog = "You owe \(entity.name) \(youOwe)."
        case (false, true, true): dialog = "\(entity.name) owes you \(owesYou), and you owe them \(youOwe)."
        }
        return .result(value: entity, dialog: dialog)
    }
}

struct SearchPeopleIntent: AppIntent {

    static var title: LocalizedStringResource = "Search People"
    static var description = IntentDescription(
        "Finds people by name, optionally only those you still have money to settle with.",
        categoryName: "People"
    )

    @Parameter(title: "Name", description: "Leave empty to include everyone.")
    var name: String?

    @Parameter(title: "Only Unsettled", description: "Only include people who owe you or whom you owe.",
               default: false)
    var onlyUnsettled: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Search people named \(\.$name)") {
            \.$onlyUnsettled
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PersonEntity]> & ProvidesDialog {
        let searchText = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var people = PersonQuery().all { searchText.isEmpty || $0.name.localizedStandardContains(searchText) }
        if onlyUnsettled {
            people = people.filter { !$0.isMe && ($0.owesYou > 0 || $0.youOwe > 0) }
        }
        let dialog: IntentDialog
        switch people.count {
        case 0: dialog = "No one matches."
        case 1: dialog = "Found \(people[0].name)."
        default: dialog = "Found \(people.count) people."
        }
        return .result(value: people, dialog: dialog)
    }
}

struct GetReceiptIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Receipt"
    static var description = IntentDescription(
        "Gets a receipt with its total, what's still unpaid, who's splitting it and its items.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$receipt)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        let entity = ReceiptEntity(from: try IntentStore.receipt(self.receipt))
        let total = format(entity.total)
        let dialog: IntentDialog = entity.unpaidAmount > 0 ?
            "\(entity.name) comes to \(total), with \(format(entity.unpaidAmount)) still unpaid." :
            "\(entity.name) comes to \(total) and is fully paid."
        return .result(value: entity, dialog: dialog)
    }
}

struct GetReceiptItemIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Item"
    static var description = IntentDescription(
        "Gets an item on a receipt, with its price, who it's for and whether it's paid.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Item")
    var item: ReceiptItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$item)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptItemEntity> & ProvidesDialog {
        let entity = ReceiptItemEntity(from: try IntentStore.item(self.item))
        let price = format(entity.price)
        let dialog: IntentDialog = entity.isPaid ?
            "\(entity.name) on \(entity.receiptName) is \(price) and paid." :
            "\(entity.name) on \(entity.receiptName) is \(price) and not paid yet."
        return .result(value: entity, dialog: dialog)
    }
}
