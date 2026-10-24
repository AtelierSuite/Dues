import Foundation
import SwiftData

var sharedModelContainer: ModelContainer = {
    newContainer()
}()

func isCloudSyncEnabled() -> Bool {
    return defaults.object(forKey: "EnableCloudSync") == nil || defaults.bool(forKey: "EnableCloudSync")
}

func newContainer() -> ModelContainer {
    let schema = Schema([
        Receipt.self, Person.self, ReceiptItem.self, DiscountItem.self, TaxItem.self
    ])
    let cloudConfiguration = ModelConfiguration(schema: schema,
                                                isStoredInMemoryOnly: false,
                                                cloudKitDatabase: isCloudSyncEnabled() ? .automatic : .none)
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
