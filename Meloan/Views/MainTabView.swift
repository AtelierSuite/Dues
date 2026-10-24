import CoreData
import Komponents
import StoreKit
import SwiftData
import SwiftUI
import TipKit

struct MainTabView: View {

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.modelContext) var modelContext
    @Environment(\.requestReview) var requestReview
    @EnvironmentObject var tabManager: TabManager
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var toastManager: ToastManager
    @AppStorage(wrappedValue: false, "ReviewPrompted", store: .standard) var hasReviewBeenPrompted: Bool
    @AppStorage(wrappedValue: 0, "LaunchCount", store: .standard) var launchCount: Int
    @Query var people: [Person]

    var body: some View {
        TabView(selection: $tabManager.selectedTab) {
            Tab("TabTitle.Receipts", systemImage: "receipt", value: TabType.receipts) {
                ReceiptsView()
            }
            Tab(value: TabType.iou) {
                IOUView()
            } label: {
                Label("TabTitle.IOU", image: "Tab.IOU")
            }
            Tab("TabTitle.People", systemImage: "person.2", value: TabType.people) {
                PeopleView()
            }
            Tab("TabTitle.Search", systemImage: "magnifyingglass", value: TabType.search) {
                SearchView()
            }
            Tab("TabTitle.More", systemImage: "gearshape", value: TabType.more) {
                MoreView()
            }
        }
        .undoToast()
        .task {
            if let screen = ScreenshotScreen.current {
                Tips.hideAllTipsForTesting()
                try? Tips.configure()
                await screen.stage(modelContext: modelContext, tabManager: tabManager,
                                   navigationManager: navigationManager)
                return
            }
            createMePerson()
            DuesApp.reloadWidget()
            try? Tips.configure([
                .displayFrequency(.immediate),
                .datastoreLocation(.applicationDefault)
            ])
            launchCount += 1
            if launchCount > 2 && !hasReviewBeenPrompted {
                requestReview()
                hasReviewBeenPrompted = true
            }
        }
        .onReceive(tabManager.$selectedTab, perform: { newValue in
            if newValue == tabManager.previouslySelectedTab {
                navigationManager.popToRoot(for: newValue)
            }
            tabManager.previouslySelectedTab = newValue
        })
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                checkForWidgetUpdates()
            }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSPersistentCloudKitContainer.eventChangedNotification
        )) { notification in
            // swiftlint:disable line_length
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                return
            }
            // swiftlint:enable line_length
            if event.endDate != nil && event.type == .import {
                // @Query views refetch on CloudKit import; nothing to do here.
            }
        }
    }

    func createMePerson() {
        if !people.contains(where: { $0.id == "ME" }) {
            let mePerson = Person(name: NSLocalizedString("People.Me", comment: ""))
            mePerson.id = "ME"
            mePerson.photo = UIImage(named: "Profile.Me.Circle")!.pngData()
            modelContext.insert(mePerson)
        } else {
            if let mePerson = people.first(where: { $0.id == "ME" }) {
                mePerson.name = NSLocalizedString("People.Me", comment: "")
            }
        }
    }

    /// The widget flips WidgetDidUpdate after an interactive toggle; the app
    /// only clears the flag — @Query views observe the store directly, so no
    /// manual fetch is needed.
    func checkForWidgetUpdates() {
        if defaults.bool(forKey: "WidgetDidUpdate") {
            defaults.set(false, forKey: "WidgetDidUpdate")
        }
    }
}
