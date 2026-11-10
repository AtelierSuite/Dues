import AppIntents
import Foundation
import SwiftData

struct PersonEntity: AppEntity {
    var id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Is Me")
    var isMe: Bool

    /// What this person owes you, as the IOU tab shows it. For you, what everyone owes you.
    @Property(title: "Owes You")
    var owesYou: Double

    /// What you owe this person, as the IOU tab shows it. For you, what you owe everyone.
    @Property(title: "You Owe")
    var youOwe: Double

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Person")
    static var defaultQuery = PersonQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(from person: Person, mePerson: Person?, everyone: [Person]) {
        self.id = person.id
        self.name = person.name
        self.isMe = person.id == "ME"
        guard let mePerson else {
            self.owesYou = .zero
            self.youOwe = .zero
            return
        }
        if person.id == mePerson.id {
            let others = everyone.filter { $0.id != mePerson.id }
            self.owesYou = others.reduce(.zero) { $0 + $1.roundedSumOwed(to: mePerson) }
            self.youOwe = others.reduce(.zero) { $0 + mePerson.roundedSumOwed(to: $1) }
        } else {
            self.owesYou = person.roundedSumOwed(to: mePerson)
            self.youOwe = mePerson.roundedSumOwed(to: person)
        }
    }

    /// Entities for the given people, with their balances against you.
    @MainActor
    static func make(from people: [Person]) -> [PersonEntity] {
        let everyone = (try? sharedModelContainer.mainContext.fetch(FetchDescriptor<Person>())) ?? []
        let mePerson = everyone.first { $0.id == "ME" }
        return people.map { PersonEntity(from: $0, mePerson: mePerson, everyone: everyone) }
    }
}

struct PersonQuery: EntityStringQuery, Sendable {
    func entities(for identifiers: [PersonEntity.ID]) async throws -> [PersonEntity] {
        return await all { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PersonEntity] {
        return await all { $0.name.localizedStandardContains(string) }
    }

    func suggestedEntities() async throws -> [PersonEntity] {
        return await all()
    }

    /// "Me" first, then everyone else by name, matching the app's people lists.
    @MainActor
    func all(where isIncluded: (Person) -> Bool = { _ in true }) -> [PersonEntity] {
        do {
            let people = try sharedModelContainer.mainContext.fetch(FetchDescriptor<Person>())
            let mePeople: [Person] = people.filter { $0.id == "ME" }
            let others: [Person] = people
                .filter { $0.id != "ME" }
                .sorted { $0.name != $1.name ? $0.name < $1.name : $0.id < $1.id }
            return PersonEntity.make(from: (mePeople + others).filter(isIncluded))
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }
}
