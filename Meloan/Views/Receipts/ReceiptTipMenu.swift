import SwiftUI

/// Adds a tip line to the draft's tax items, either as a percentage of the pre-tax
/// subtotal or as the difference needed to round the total up.
struct ReceiptTipMenu: View {

    @AppStorage(wrappedValue: "", "CurrencySymbol", store: defaults) var currencySymbol: String
    @Binding var taxItems: [ReceiptDraft.Tax]
    /// Items less discounts, before tax and service charge.
    var subtotal: Double
    /// What the receipt will total once saved, including automatic charges but not the tip.
    var totalBeforeTip: Double
    @State var isCustomPercentagePresented: Bool = false
    @State var customPercentage: Double?

    var body: some View {
        Menu {
            Section("Receipt.Tip.Percentage") {
                ForEach(Gratuity.presetPercentages, id: \.self) { percentage in
                    Button {
                        addTip(Gratuity.amount(percentage: percentage, of: subtotal))
                    } label: {
                        Text(percentage / 100.0, format: .percent)
                        Text(verbatim: format(Gratuity.amount(percentage: percentage, of: subtotal)))
                    }
                }
                Button("Receipt.Tip.CustomPercentage") {
                    customPercentage = nil
                    isCustomPercentagePresented = true
                }
            }
            Section("Receipt.Tip.RoundUp") {
                ForEach(Gratuity.roundUpOptions(total: totalBeforeTip, currencyCode: currencySymbol),
                        id: \.self) { option in
                    Button {
                        addTip(option.tip)
                    } label: {
                        Text(verbatim: format(option.target))
                        Text(verbatim: "+\(format(option.tip))")
                    }
                }
            }
        } label: {
            Image(systemName: "hand.thumbsup.circle")
        }
        .accessibilityLabel("Receipt.Tip.Add")
        .disabled(subtotal <= 0)
        .alert("Receipt.Tip.CustomPercentage.Title", isPresented: $isCustomPercentagePresented) {
            TextField("Receipt.Tip.CustomPercentage.Placeholder", value: $customPercentage, format: .number)
                .keyboardType(.decimalPad)
            Button("Shared.Cancel", role: .cancel) { }
            Button("Receipt.Tip.Add") {
                if let customPercentage, customPercentage > 0 {
                    addTip(Gratuity.amount(percentage: customPercentage, of: subtotal))
                }
            }
        } message: {
            Text("Receipt.Tip.CustomPercentage.Message")
        }
    }

    /// Keeps one tip per receipt: re-tipping updates the existing line (keeping any name
    /// the user gave it) so recalculating after editing items is a single tap.
    func addTip(_ amount: Double) {
        guard amount > 0 else { return }
        var newTaxItems = taxItems
        if let index = newTaxItems.firstIndex(where: { Gratuity.isTip(id: $0.id) }) {
            newTaxItems[index].price = amount
        } else {
            newTaxItems.append(ReceiptDraft.Tax(id: Gratuity.idPrefix + UUID().uuidString,
                                                name: NSLocalizedString("Receipt.Tip", comment: ""),
                                                price: amount, dateAdded: Date.now))
        }
        taxItems = newTaxItems
    }
}
