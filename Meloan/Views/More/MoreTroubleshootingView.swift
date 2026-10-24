import Komponents
import SwiftData
import SwiftUI

struct MoreTroubleshootingView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @Query var people: [Person]
    @Query var receipts: [Receipt]
    @State var isDeleteConfirming: Bool = false
    @State var isSettingsResetConfirming: Bool = false

    var body: some View {
        List {
            Section {
                Button {
                    Task { @MainActor in
                        _ = try? modelContext.fetch(FetchDescriptor<ReceiptItem>())
                    }
                } label: {
                    Text("More.Data.AttemptReloadData")
                }
                Button {
                    DuesApp.reloadWidget()
                } label: {
                    Text("More.Data.ReloadWidgets")
                }
            }
            Section {
                Button {
                    isSettingsResetConfirming = true
                } label: {
                    Text("More.Data.ResetAllSettings")
                        .foregroundStyle(.red)
                }
                Button {
                    isDeleteConfirming = true
                } label: {
                    Text("More.Data.DeleteAll")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Alert.ResetAllSettings.Title", isPresented: $isSettingsResetConfirming) {
            Button(role: .destructive) {
                resetSettings()
            } label: {
                Text("Shared.Yes")
            }
            Button(role: .cancel) { } label: {
                Text("Shared.No")
            }
        } message: {
            Text("Alert.ResetAllSettings.Text")
        }
        .alert("Alert.DeleteAll.Title", isPresented: $isDeleteConfirming) {
            Button(role: .destructive) {
                deleteAllData()
                navigationManager.popAll()
            } label: {
                Text("Shared.Yes")
            }
            Button(role: .cancel) { } label: {
                Text("Shared.No")
            }
        } message: {
            Text("Alert.DeleteAll.Text")
        }
        .navigationTitle("ViewTitle.Troubleshooting")
    }

    func deleteAllData() {
        for receipt in receipts {
            modelContext.delete(receipt)
        }
        for person in people where person.id != "ME" {
            modelContext.delete(person)
        }
        try? modelContext.save()
        // Return to a clean first-run state.
        defaults.set(false, forKey: "SampleDataCreated")
        defaults.removeObject(forKey: "SearchHistory")
        DuesApp.reloadWidget()
    }

    func resetSettings() {
        defaults.removePersistentDomain(forName: "group.com.tsubuzaki.Meloan")
        defaults.synchronize()
    }
}
