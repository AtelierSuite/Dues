import AppIntents
import Foundation

struct OpenReceiptIntent: OpenIntent {

    static var title: LocalizedStringResource = "Open Receipt"
    static var description = IntentDescription(
        "Opens a receipt in the app.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var target: ReceiptEntity

    @Dependency var tabManager: TabManager
    @Dependency var navigationManager: NavigationManager

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let receipt = try IntentStore.receipt(target)
        if tabManager.selectedTab != .receipts {
            tabManager.selectedTab = .receipts
            // Pushed after the tab change settles, since reselecting a tab pops it to the root.
            try? await Task.sleep(for: .milliseconds(500))
        }
        navigationManager.popToRoot(for: .receipts)
        navigationManager.push(.receiptDetail(receipt: receipt), for: .receipts)
        return .result()
    }
}
