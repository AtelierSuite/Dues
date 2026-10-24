import SwiftUI
import SwiftData
import WidgetKit

@main
struct DuesApp: App {

    @StateObject var tabManager = TabManager()
    @StateObject var navigationManager = NavigationManager()
    @StateObject var toastManager = ToastManager()

    init() {
        // The store on disk is seeded for the widgets, so it is kept off iCloud.
        if ScreenshotScreen.current == .widgets {
            defaults.set(false, forKey: "EnableCloudSync")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(tabManager)
                .environmentObject(navigationManager)
                .environmentObject(toastManager)
        }
        .modelContainer(ScreenshotScreen.current?.modelContainer ?? sharedModelContainer)
    }

    static func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
