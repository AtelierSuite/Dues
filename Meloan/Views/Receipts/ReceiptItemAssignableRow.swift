import SwiftData
import SwiftUI

struct ReceiptItemAssignableRow: View {

    @Binding var item: ReceiptDraft.Item
    var peopleWhoParticipated: [Person]
    var placeholderText: String
    @ScaledMetric(relativeTo: .subheadline) var priceFieldWidth: CGFloat = 120.0

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            Menu {
                Button {
                    item.person = nil
                } label: {
                    Image("Profile.Shared.Circle")
                    Text("Shared.Shared")
                }
                ForEach(peopleWhoParticipated) { person in
                    Button {
                        item.person = person
                    } label: {
                        PersonRow(person: person)
                    }
                }
            } label: {
                PersonAvatar(person: item.person, size: 30.0)
            }
            .fixedSize()
            .accessibilityLabel(Text("Receipt.Item.Assignee"))
            .accessibilityValue(Text(item.person?.name ?? NSLocalizedString("Shared.Shared", comment: "")))
            TextField(LocalizedStringKey(placeholderText), text: $item.name)
                .textInputAutocapitalization(.words)
            Divider()
            TextField("Receipt.Price", value: $item.price, format: priceFormatStyle())
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .font(.subheadline)
                .monospaced()
                .frame(maxWidth: priceFieldWidth)
        }
        .onChange(of: peopleWhoParticipated, initial: false) { _, _ in
            if let personWhoOrdered = item.person {
                if !peopleWhoParticipated.contains(where: { $0.id == personWhoOrdered.id }) {
                    item.person = nil
                }
            }
        }
    }
}
