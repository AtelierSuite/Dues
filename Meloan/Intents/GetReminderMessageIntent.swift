import AppIntents
import Foundation

struct GetReminderMessageIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Reminder Message"
    static var description = IntentDescription(
        "Gets a friendly message reminding someone what they owe you, the same one the IOU tab shares.",
        categoryName: "Sharing"
    )

    @Parameter(title: "Person")
    var person: PersonEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get a reminder message for \(\.$person)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let person = try IntentStore.person(self.person)
        let entity = PersonEntity.make(from: [person])[0]
        guard !entity.isMe, entity.owesYou > 0 else { throw IntentError.nothingOwed(entity.name) }
        return .result(value: hey(person, youOweMe: entity.owesYou))
    }
}
