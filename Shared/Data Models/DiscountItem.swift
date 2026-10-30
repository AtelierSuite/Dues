import Foundation
import SwiftData

@Model
final class DiscountItem {
    var id: String = UUID().uuidString
    var name: String = ""
    var price: Double = 0.0
    @Relationship(inverse: \Receipt.discountItems) var receipts: [Receipt]? = []
    var dateAdded: Date = Date.now

    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}

extension DiscountItem {
    /// Discounts saved before they had an ID (by an older version, on this or another device)
    /// all take the same default ID. Gives every duplicate a fresh one so they can be told apart.
    static func repairDuplicateIDs(in modelContext: ModelContext) {
        guard let discountItems = try? modelContext.fetch(FetchDescriptor<DiscountItem>()) else { return }
        var seenIDs = Set<String>()
        var hasChanges = false
        for discountItem in discountItems where !seenIDs.insert(discountItem.id).inserted {
            discountItem.id = UUID().uuidString
            hasChanges = true
        }
        if hasChanges {
            try? modelContext.save()
        }
    }
}
