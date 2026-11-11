import SwiftUI

@MainActor
final class TabManager: ObservableObject {
    @Published var selectedTab: TabType = .receipts
    @Published var previouslySelectedTab: TabType = .receipts
}
