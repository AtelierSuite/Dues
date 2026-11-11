import AppIntents
import Foundation

struct GetReceiptTextIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Receipt Text"
    static var description = IntentDescription(
        "Gets a receipt as plain text, with its items, discounts, taxes and totals, ready to paste into a message.",
        categoryName: "Sharing"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$receipt) as text")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let receipt = try IntentStore.receipt(self.receipt)
        return .result(value: receipt.shareText())
    }
}
