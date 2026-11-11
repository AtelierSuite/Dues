import AppIntents
import Foundation

struct DeleteReceiptIntent: DeleteIntent {

    static var title: LocalizedStringResource = "Delete Receipt"
    static var description = IntentDescription(
        "Deletes receipts, with their items, taxes and discounts. Asks before deleting.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipts")
    var entities: [ReceiptEntity]

    static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$entities)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let receipts = try entities.map { try IntentStore.receipt($0) }
        let names = ListFormatter.localizedString(byJoining: receipts.map { $0.name })
        try await requestConfirmation(dialog: "Delete \(names)? This can't be undone.")

        for receipt in receipts {
            IntentStore.context.delete(receipt)
        }
        try IntentStore.save()
        return .result(dialog: "Deleted \(names).")
    }
}
