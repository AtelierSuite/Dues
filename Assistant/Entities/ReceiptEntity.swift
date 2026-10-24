import AppIntents
import Foundation
import SwiftData

struct ReceiptEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Receipt")
    static var defaultQuery = ReceiptQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: name)
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(from receipt: Receipt) {
        self.id = receipt.id
        self.name = receipt.name
    }
}

struct ReceiptQuery: EntityQuery, Sendable {
    func entities(for identifiers: [ReceiptEntity.ID]) async throws -> [ReceiptEntity] {
        return await all().filter { identifiers.contains($0.id) }
     }

     func suggestedEntities() async throws -> [ReceiptEntity] {
         return await all()
     }

     func defaultResult() async -> ReceiptEntity? {
         return try? await suggestedEntities().first
     }

    @MainActor
    func all() -> [ReceiptEntity] {
        // Reuse the shared container instead of opening a second, divergent store.
        do {
            var descriptor = FetchDescriptor<Receipt>()
            descriptor.sortBy = [SortDescriptor(\.name, order: .forward)]
            return try sharedModelContainer
                .mainContext.fetch(descriptor)
                .map { ReceiptEntity(from: $0) }
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }
}
