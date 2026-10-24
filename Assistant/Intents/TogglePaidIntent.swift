import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct TogglePaidIntent: AppIntent {

    static var title: LocalizedStringResource = "Receipt.MarkPaidIntent.Title"
    static var description = IntentDescription("Receipt.MarkPaidIntent.Description")

    @Parameter(title: "Receipt.MarkPaidIntent.ItemID") var id: String

    init() {
        self.id = ""
    }

    init(id: String) {
        // IMPORTANT: Do NOT remove, if not Swift will whine about String not being IntentParameter<String>.
        self.id = id
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let receiptItem = getReceiptItem() {
            // Mirror in-app settlement so shared items keep peopleWhoPaid consistent.
            if let receipt = receiptItem.receipts?.first {
                receipt.toggleSettled(receiptItem)
            } else {
                receiptItem.paid.toggle()
            }
            try? sharedModelContainer.mainContext.save()
            // Set flag so main app knows to reload data
            defaults.set(true, forKey: "WidgetDidUpdate")
            WidgetCenter.shared.reloadTimelines(ofKind: "com.tsubuzaki.Meloan.ReceiptWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "com.tsubuzaki.Meloan.ReceiptItemsWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "com.tsubuzaki.Meloan.ReceiptIOUWidget")
        }
        return .result()
    }

    @MainActor
    func getReceiptItem() -> ReceiptItem? {
        let itemID = id
        var descriptor = FetchDescriptor<ReceiptItem>(predicate: #Predicate { $0.id == itemID })
        descriptor.fetchLimit = 1
        return (try? sharedModelContainer.mainContext.fetch(descriptor))?.first
    }
}
