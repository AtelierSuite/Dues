import AppIntents
import Foundation

struct DeleteReceiptItemIntent: DeleteIntent {

    static var title: LocalizedStringResource = "Delete Item"
    static var description = IntentDescription(
        "Deletes items from their receipts. Asks before deleting.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Items")
    var entities: [ReceiptItemEntity]

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$entities)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let items = try entities.map { try IntentStore.item($0) }
        let names = ListFormatter.localizedString(byJoining: items.map { $0.name })
        try await requestConfirmation(dialog: "Delete \(names)? This can't be undone.")

        var receipts: [Receipt] = []
        for item in items {
            if let receipt = item.receipts?.first {
                receipt.receiptItems?.removeAll { $0.id == item.id }
                if !receipts.contains(where: { $0.id == receipt.id }) {
                    receipts.append(receipt)
                }
            }
            IntentStore.context.delete(item)
        }
        // The automatic charges follow the items left on each receipt.
        for receipt in receipts {
            receipt.applyAutoCharges(in: IntentStore.context)
        }
        try IntentStore.save()
        return .result(dialog: "Deleted \(names).")
    }
}
