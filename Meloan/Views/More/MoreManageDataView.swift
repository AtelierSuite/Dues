import CloudKit
import CloudKitSyncMonitor

import SwiftData
import SwiftUI

struct MoreManageDataView: View {

    @Environment(\.modelContext) var modelContext
    @ObservedObject var syncMonitor = SyncMonitor.shared
    @AppStorage(wrappedValue: true, "EnableCloudSync", store: defaults) var enableCloudSync: Bool
    @AppStorage(wrappedValue: false, "SampleDataCreated", store: defaults) var sampleDataCreated: Bool
    @State var isRestartAlertPresented: Bool = false

    var body: some View {
        List {
            Section {
                if enableCloudSync {
                    VStack(alignment: .center, spacing: 16.0) {
                        Group {
                            if syncMonitor.syncStateSummary.isBroken {
                                Image(systemName: "xmark.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.red)
                            } else if syncMonitor.syncStateSummary.inProgress {
                                Image(systemName: "arrow.triangle.2.circlepath.icloud.fill")
                                    .resizable()
                                    .foregroundStyle(.primary)
                            } else {
                                switch syncMonitor.syncStateSummary {
                                case .notStarted, .succeeded:
                                    Image(systemName: "checkmark.icloud.fill")
                                        .resizable()
                                        .foregroundStyle(.green)
                                case .noNetwork:
                                    Image(systemName: "bolt.horizontal.icloud.fill")
                                        .resizable()
                                        .foregroundStyle(.orange)
                                default:
                                    Image(systemName: "exclamationmark.icloud.fill")
                                        .resizable()
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .symbolRenderingMode(.multicolor)
                        .scaledToFit()
                        .frame(width: 64.0, height: 64.0)
                        Group {
                            if syncMonitor.syncStateSummary.isBroken {
                                Text("More.Data.Sync.State.Error")
                            } else if syncMonitor.syncStateSummary.inProgress {
                                Text("More.Data.Sync.State.InProgress")
                            } else {
                                switch syncMonitor.syncStateSummary {
                                case .notStarted, .succeeded:
                                    Text("More.Data.Sync.State.Synced")
                                case .noNetwork:
                                    Text("More.Data.Sync.State.NoNetwork")
                                default:
                                    Text("More.Data.Sync.State.NotSyncing")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .alignmentGuide(.listRowSeparatorLeading, computeValue: { _ in
                        0
                    })
                } else {
                    VStack(alignment: .center, spacing: 16.0) {
                        Image(systemName: "icloud.slash.fill")
                            .resizable()
                            .symbolRenderingMode(.multicolor)
                            .scaledToFit()
                            .frame(width: 64.0, height: 64.0)
                            .foregroundStyle(.secondary)
                        Text("More.Data.Sync.State.Disabled")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                    .alignmentGuide(.listRowSeparatorLeading, computeValue: { _ in
                        0
                    })
                }
                Toggle("More.Data.Sync", isOn: $enableCloudSync)
            } header: {
                Text("More.Data.Sync")
            } footer: {
                Text("More.Data.Sync.Description")
                    .font(.body)
            }
            if !sampleDataCreated {
                Section {
                    Button {
                        createSampleData()
                    } label: {
                        Text("More.Data.SampleData.Create")
                    }
                } header: {
                    Text("More.Data.SampleData")
                } footer: {
                    Text("More.Data.SampleData.Description")
                        .font(.body)
                }
            }
        }
        .onChange(of: enableCloudSync) { _, _ in
            isRestartAlertPresented = true
        }
        .alert("More.Data.Sync.RestartRequired.Title", isPresented: $isRestartAlertPresented) {
            Button("Shared.OK") { }
        } message: {
            Text("More.Data.Sync.RestartRequired.Message")
        }
        .navigationTitle("ViewTitle.Data")
    }

    func createSampleData() {
        let person1 = Person(name: NSLocalizedString("SampleData.Akagi", comment: ""),
                             photo: UIImage(named: "Akagi")!.pngData())
        let person2 = Person(name: NSLocalizedString("SampleData.Muramoto", comment: ""),
                             photo: UIImage(named: "Muramoto")!.pngData())
        let person3 = Person(name: NSLocalizedString("SampleData.Kuroko", comment: ""),
                             photo: UIImage(named: "Kuroko")!.pngData())
        let receiptItem1 = ReceiptItem(name: NSLocalizedString("SampleData.Item1", comment: ""),
                                       price: 42.00, amount: 1)
        let receiptItem2 = ReceiptItem(name: NSLocalizedString("SampleData.Item2", comment: ""),
                                       price: 12.00, amount: 1)
        let receiptItem3 = ReceiptItem(name: NSLocalizedString("SampleData.Item3", comment: ""),
                                       price: 11.00, amount: 1)
        let receiptItem4 = ReceiptItem(name: NSLocalizedString("SampleData.Item4", comment: ""),
                                       price: 16.00, amount: 1)
        let receiptItem5 = ReceiptItem(name: NSLocalizedString("SampleData.Item5", comment: ""),
                                       price: 1.00, amount: 3)
        let discountItem = DiscountItem(name: NSLocalizedString("SampleData.Discount", comment: ""),
                                        price: 6.00)
        let taxItem1 = TaxItem(name: NSLocalizedString("SampleData.TaxItem1", comment: ""),
                               price: 8.10)
        let taxItem2 = TaxItem(name: NSLocalizedString("SampleData.TaxItem2", comment: ""),
                               price: 6.48)
        let receipt = Receipt(name: NSLocalizedString("SampleData.ReceiptName", comment: ""))
        person1.id = "SAMPLE-PERSON-1"
        person2.id = "SAMPLE-PERSON-2"
        person3.id = "SAMPLE-PERSON-3"
        modelContext.insert(person1)
        modelContext.insert(person2)
        modelContext.insert(person3)
        receiptItem2.setPurchaser(to: person1)
        receiptItem3.setPurchaser(to: person2)
        receiptItem4.setPurchaser(to: person3)
        receipt.id = "SAMPLE-RECEIPT"
        receipt.addReceiptItems(from: [receiptItem1, receiptItem2, receiptItem3,
                                       receiptItem4, receiptItem5])
        receipt.addDiscountItems(from: [discountItem])
        receipt.addTaxItems(from: [taxItem1, taxItem2])
        receipt.setPersonWhoPaid(to: person1)
        receipt.addPeopleWhoParticipated(from: [person1, person2, person3])
        modelContext.insert(receipt)
        withAnimation {
            sampleDataCreated = true
        }
    }
}
