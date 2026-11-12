import AppIntents
import Foundation

struct GetIOUSummaryIntent: AppIntent {

    static var title: LocalizedStringResource = "Get IOU Summary"
    static var description = IntentDescription(
        "Gets everyone you still have money to settle with: who owes you and whom you owe.",
        categoryName: "People"
    )

    static var parameterSummary: some ParameterSummary {
        Summary("Get the IOU summary")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PersonEntity]> & ProvidesDialog {
        let unsettled = PersonQuery().all().filter { !$0.isMe && ($0.owesYou > 0 || $0.youOwe > 0) }
        guard !unsettled.isEmpty else {
            return .result(value: [], dialog: "Everyone's settled up with you.")
        }
        var balances: [String] = []
        for person in unsettled {
            if person.owesYou > 0 {
                balances.append(String(localized: "\(person.name) owes you \(format(person.owesYou))"))
            }
            if person.youOwe > 0 {
                balances.append(String(localized: "you owe \(person.name) \(format(person.youOwe))"))
            }
        }
        let list = ListFormatter.localizedString(byJoining: balances)
        // Balances can start with "you owe", which needs a capital at the start of the sentence.
        let summary = list.prefix(1).localizedUppercase + list.dropFirst()
        return .result(value: unsettled, dialog: IntentDialog(stringLiteral: String(localized: "\(summary).")))
    }
}
