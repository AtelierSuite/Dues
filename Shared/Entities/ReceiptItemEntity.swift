import AppIntents
import Foundation
import SwiftData

struct ReceiptItemEntity: AppEntity {
    var id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Price")
    var price: Double

    @Property(title: "Quantity")
    var quantity: Int

    @Property(title: "Paid")
    var isPaid: Bool

    /// Who the item belongs to; empty when it is shared by everyone on the receipt.
    @Property(title: "Belongs To")
    var personName: String?

    @Property(title: "Receipt")
    var receiptName: String

    var receiptID: String?

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Receipt Item")
    static var defaultQuery = ReceiptItemQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(receiptName) · \(format(price))")
    }

    init(from item: ReceiptItem) {
        let receipt = item.receipts?.first
        self.id = item.id
        self.name = item.name
        self.price = item.price
        self.quantity = item.amount
        self.isPaid = item.paid
        self.personName = item.person?.name
        self.receiptName = receipt?.name ?? ""
        self.receiptID = receipt?.id
    }
}

struct ReceiptItemQuery: EntityStringQuery, Sendable {
    func entities(for identifiers: [ReceiptItemEntity.ID]) async throws -> [ReceiptItemEntity] {
        return await fetch { identifiers.contains($0.id) }
    }

    /// Matches the item's own name, or its receipt's, so "the wine from Dinner" can resolve.
    func entities(matching string: String) async throws -> [ReceiptItemEntity] {
        return await fetch { item in
            item.name.localizedStandardContains(string) ||
            (item.receipts?.first?.name.localizedStandardContains(string) ?? false)
        }
    }

    /// Unpaid items first, newest receipts first: the likeliest things to mark paid.
    func suggestedEntities() async throws -> [ReceiptItemEntity] {
        return await fetch { !$0.paid }
    }

    @MainActor
    private func fetch(where isIncluded: (ReceiptItem) -> Bool) -> [ReceiptItemEntity] {
        do {
            var descriptor = FetchDescriptor<ReceiptItem>()
            descriptor.sortBy = [SortDescriptor(\.dateAdded, order: .reverse)]
            return try sharedModelContainer.mainContext.fetch(descriptor)
                .filter(isIncluded)
                .map { ReceiptItemEntity(from: $0) }
        } catch {
            debugPrint(error.localizedDescription)
            return []
        }
    }
}
