import AppIntents
import Foundation
import SwiftData

struct PersonEntity: AppEntity {
    var id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Is Me")
    var isMe: Bool

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Person")
    static var defaultQuery = PersonQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(from person: Person) {
        self.id = person.id
        self.name = person.name
        self.isMe = person.id == "ME"
    }
}

struct PersonQuery: EntityStringQuery, Sendable {
    func entities(for identifiers: [PersonEntity.ID]) async throws -> [PersonEntity] {
        return await all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PersonEntity] {
        return await all().filter { $0.name.localizedStandardContains(string) }
    }

    func suggestedEntities() async throws -> [PersonEntity] {
        return await all()
    }

    /// "Me" first, then everyone else by name, matching the app's people lists.
    @MainActor
    func all() -> [PersonEntity] {
        do {
            let people = try sharedModelContainer.mainContext.fetch(FetchDescriptor<Person>())
            let mePeople: [Person] = people.filter { $0.id == "ME" }
            let others: [Person] = people
                .filter { $0.id != "ME" }
                .sorted { $0.name != $1.name ? $0.name < $1.name : $0.id < $1.id }
            return (mePeople + others).map { PersonEntity(from: $0) }
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }
}
