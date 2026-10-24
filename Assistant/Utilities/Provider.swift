import Foundation
import SwiftData
import WidgetKit

struct Provider: AppIntentTimelineProvider {

    typealias Entry = ReceiptEntry
    typealias Intent = ReceiptIntent

    func placeholder(in context: Context) -> ReceiptEntry {
        ReceiptEntry()
    }

    @MainActor
    func snapshot(for configuration: ReceiptIntent, in context: Context) async -> ReceiptEntry {
        if let receipt = configuration.receipt {
            return ReceiptEntry(date: Date.now, receipt: fetchReceipt(id: receipt.id))
        }
        return ReceiptEntry()
    }

    @MainActor
    func timeline(for configuration: ReceiptIntent, in context: Context) async -> Timeline<ReceiptEntry> {
        if let receipt = configuration.receipt {
            return Timeline(entries: [ReceiptEntry(receipt: fetchReceipt(id: receipt.id))], policy: .atEnd)
        }
        return Timeline(entries: [], policy: .atEnd)
    }

    @MainActor
    private func fetchReceipt(id: String) -> Receipt? {
        var descriptor = FetchDescriptor<Receipt>(predicate: #Predicate<Receipt> { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try sharedModelContainer.mainContext.fetch(descriptor).first
        } catch {
            debugPrint(error.localizedDescription)
            return nil
        }
    }
}
