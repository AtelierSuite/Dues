import SwiftData
import SwiftUI

/// A screen staged for the App Store screenshots, from the `-ScreenshotScreen` launch argument
/// that `Assets/App Store/capture.sh` passes. Any of them fills the app with demo data.
///
/// Only honored in debug builds on the Simulator, since staging replaces the data in the store.
enum ScreenshotScreen: String {
    /// Seeds the store on disk rather than in memory, so that the widgets can show the demo
    /// receipts once they are placed on the Home Screen by hand.
    case widgets
    case receipts
    case receipt
    case pdf
    case iou
    case searchPeople = "search-people"
    case searchItems = "search-items"
    case more

    static let current: ScreenshotScreen? = {
        #if DEBUG && targetEnvironment(simulator)
        UserDefaults.standard.string(forKey: "ScreenshotScreen").flatMap(ScreenshotScreen.init)
        #else
        nil
        #endif
    }()

    /// The container the app runs on. Every screen but the widgets is held in memory only.
    var modelContainer: ModelContainer? {
        self == .widgets ? nil : DemoData.inMemoryContainer
    }

    var tab: TabType {
        switch self {
        case .widgets, .receipts, .receipt, .pdf: .receipts
        case .iou: .iou
        case .searchPeople, .searchItems: .search
        case .more: .more
        }
    }

    var searchTerm: String {
        switch self {
        case .searchPeople: DemoData.peopleSearchTerm
        case .searchItems: DemoData.itemsSearchTerm
        default: ""
        }
    }

    /// The receipt pushed onto the Receipts tab.
    var receiptID: String? {
        switch self {
        case .receipt: DemoData.teamDinnerID
        case .pdf: DemoData.dinnerWithAliceID
        default: nil
        }
    }

    /// Replaces the data with the demo data, then opens the screen.
    @MainActor
    func stage(modelContext: ModelContext, tabManager: TabManager, navigationManager: NavigationManager) async {
        DemoData.replaceAll(in: modelContext)
        DuesApp.reloadWidget()
        if tabManager.selectedTab != tab {
            tabManager.selectedTab = tab
        }
        guard let receiptID else { return }
        // Pushed after the tab change settles, since reselecting a tab pops it to the root.
        try? await Task.sleep(for: .milliseconds(500))
        var descriptor = FetchDescriptor<Receipt>(predicate: #Predicate { $0.id == receiptID })
        descriptor.fetchLimit = 1
        if let receipt = try? modelContext.fetch(descriptor).first {
            navigationManager.push(.receiptDetail(receipt: receipt), for: tab)
        }
    }
}
