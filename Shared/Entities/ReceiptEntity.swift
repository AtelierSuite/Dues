import AppIntents
import Foundation
import SwiftData

struct ReceiptEntity: AppEntity {
    var id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Total")
    var total: Double

    @Property(title: "Unpaid Amount")
    var unpaidAmount: Double

    @Property(title: "Fully Paid")
    var isPaid: Bool

    @Property(title: "Paid By")
    var payerName: String?

    @Property(title: "Participants")
    var participantNames: [String]

    @Property(title: "Date Added")
    var dateAdded: Date

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Receipt")
    static var defaultQuery = ReceiptQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(format(total))")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.total = .zero
        self.unpaidAmount = .zero
        self.isPaid = false
        self.payerName = nil
        self.participantNames = []
        self.dateAdded = .now
    }

    init(from receipt: Receipt) {
        self.id = receipt.id
        self.name = receipt.name
        self.total = receipt.sum()
        self.unpaidAmount = receipt.sumUnpaid()
        self.isPaid = receipt.isPaid()
        self.payerName = receipt.personWhoPaid?.name
        self.participantNames = receipt.participants().map { $0.name }
        self.dateAdded = receipt.dateAdded
    }
}

struct ReceiptQuery: EntityStringQuery, Sendable {
    func entities(for identifiers: [ReceiptEntity.ID]) async throws -> [ReceiptEntity] {
        return await all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ReceiptEntity] {
        return await all().filter { $0.name.localizedStandardContains(string) }
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
