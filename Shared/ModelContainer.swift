import Foundation
import SwiftData

var sharedModelContainer: ModelContainer = {
    newContainer()
}()

func isCloudSyncEnabled() -> Bool {
    return defaults.object(forKey: "EnableCloudSync") == nil || defaults.bool(forKey: "EnableCloudSync")
}

/// Whether this code is running inside an app extension (e.g. the widget extension) rather than the app.
private var isRunningInExtension: Bool {
    Bundle.main.bundleURL.pathExtension == "appex"
}

func newContainer() -> ModelContainer {
    let schema = Schema([
        Receipt.self, Person.self, ReceiptItem.self, DiscountItem.self, TaxItem.self
    ])
    // Only the app mirrors the store to CloudKit. Extensions open the same app-group store locally,
    // and the app exports their changes from persistent history the next time it syncs.
    let syncsToCloud = isCloudSyncEnabled() && !isRunningInExtension
    let cloudConfiguration = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: false,
                                                cloudKitDatabase: syncsToCloud ? .automatic : .none)
    if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
        return container
    }
    // Fallback: local store without CloudKit.
    let localConfiguration = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: false,
                                                cloudKitDatabase: .none)
    if let container = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
        return container
    }
    // Last resort: in-memory store so the app still launches.
    do {
        let memoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [memoryConfiguration])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}
