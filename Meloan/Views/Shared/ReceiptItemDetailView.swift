import SwiftUI

struct ReceiptItemDetailView: View {

    @State var receiptItem: ReceiptItem

    var body: some View {
        List {
            Section {
                HStack(alignment: .center, spacing: 16.0) {
                    Label("Receipt.Item.Price", systemImage: "tag")
                    Spacer()
                    Text(format(receiptItem.price))
                        .foregroundStyle(.secondary)
                }
                if let personWhoOrdered = receiptItem.person {
                    HStack(alignment: .center, spacing: 16.0) {
                        Label("Receipt.Item.Orderer", systemImage: "person.crop.circle")
                        Spacer()
                        PersonRow(person: personWhoOrdered)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(alignment: .center, spacing: 16.0) {
                    Label("Receipt.Item.Paid", systemImage: "checkmark.circle")
                    Spacer()
                    Text(receiptItem.paid ? "Receipt.Item.Paid.Yes" : "Receipt.Item.Paid.No")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Receipt.Item.BasicInformation")
            }
            Section {
                ForEach(receiptItem.receipts ?? []) { receipt in
                    NavigationLink(value: ViewPath.receiptDetail(receipt: receipt)) {
                        Label(receipt.name, systemImage: "receipt")
                    }
                }
            } header: {
                Text("Receipt.Item.ReceiptInformation")
            }
        }
        .navigationTitle(receiptItem.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
