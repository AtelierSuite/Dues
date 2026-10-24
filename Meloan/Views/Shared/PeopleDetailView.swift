import SwiftUI

struct PeopleDetailView: View {

    @Environment(\.dismiss) var dismiss
    @State var person: Person

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    Group {
                        if let photo = person.photo,
                           let image = UIImage(data: photo) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image("Profile.Generic")
                                .resizable()
                        }
                    }
                    .frame(width: 144, height: 144)
                    .clipShape(Circle())
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            Section {
                HStack(alignment: .center, spacing: 16.0) {
                    Label("Person.Name", systemImage: "person")
                    Spacer()
                    Text(person.name)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Person.BasicInformation")
            }
            if let receiptsPaid = person.receiptsPaid, !receiptsPaid.isEmpty {
                Section {
                    ForEach(receiptsPaid) { receipt in
                        NavigationLink(value: ViewPath.receiptDetail(receipt: receipt)) {
                            Label(receipt.name, systemImage: "receipt")
                        }
                    }
                } header: {
                    Text("Person.ReceiptsPaid")
                }
            }
            if let receiptsParticipated = person.receiptsParticipated, !receiptsParticipated.isEmpty {
                Section {
                    ForEach(receiptsParticipated) { receipt in
                        NavigationLink(value: ViewPath.receiptDetail(receipt: receipt)) {
                            Label(receipt.name, systemImage: "receipt")
                        }
                    }
                } header: {
                    Text("Person.ReceiptsParticipated")
                }
            }
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
