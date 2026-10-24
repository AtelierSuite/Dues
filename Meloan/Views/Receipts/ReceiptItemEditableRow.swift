import SwiftUI

struct ReceiptItemEditableRow: View {

    @Binding var name: String
    @Binding var price: Double
    var placeholderText: String
    var isDisabled: Bool

    init(item: Binding<ReceiptDraft.Discount>, placeholderText: String) {
        self._name = item.name
        self._price = item.price
        self.placeholderText = placeholderText
        self.isDisabled = false
    }

    init(item: Binding<ReceiptDraft.Tax>, placeholderText: String) {
        self._name = item.name
        self._price = item.price
        self.placeholderText = placeholderText
        self.isDisabled = item.wrappedValue.id.starts(with: "AUTOTAX-")
            || item.wrappedValue.id.starts(with: "AUTOTEN-")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16.0) {
            TextField(LocalizedStringKey(placeholderText), text: $name)
                .textInputAutocapitalization(.words)
            Divider()
            TextField("Receipt.Price", value: $price, format: priceFormatStyle())
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .monospaced()
                .font(.system(size: 14.0))
                .frame(maxWidth: 120.0)
        }
        .disabled(isDisabled)
        .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
    }
}
