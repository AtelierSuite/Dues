import AppIntents
import Foundation

/// Whether a charge or discount is a fixed amount or a percentage of the items.
enum ChargeCalculation: String, AppEnum {
    case amount
    case percentage

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Calculation")
    static var caseDisplayRepresentations: [ChargeCalculation: DisplayRepresentation] = [
        .amount: "Amount",
        .percentage: "Percentage"
    ]

    /// The value as money: itself for an amount, or that percentage of `itemsTotal`.
    func price(for value: Double, itemsTotal: Double) -> Double {
        switch self {
        case .amount: value
        case .percentage: Gratuity.roundedToCurrency(itemsTotal * value / 100.0)
        }
    }
}

struct AddTaxIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Tax"
    static var description = IntentDescription(
        "Adds a tax or charge line to a receipt. Your own tax replaces the automatic tax and service charge.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    @Parameter(title: "Value", requestValueDialog: "How much is the tax?")
    var value: Double

    @Parameter(title: "Calculation", default: .amount)
    var calculation: ChargeCalculation

    @Parameter(title: "Name", description: "Leave empty to call it Tax.")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add tax of \(\.$value) to \(\.$receipt)") {
            \.$calculation
            \.$name
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        guard value >= 0 else { throw IntentError.negativePrice }
        let receipt = try IntentStore.receipt(self.receipt)
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let taxName = trimmedName.isEmpty ? String(localized: "Tax") : trimmedName
        let price = calculation.price(for: value, itemsTotal: receipt.sumOfItems())

        receipt.addTaxItems(from: [TaxItem(name: taxName, price: price)])
        // A tax of the user's own switches the automatic charges off, as in the editor.
        receipt.applyAutoCharges(in: IntentStore.context)
        try IntentStore.save()

        let total = format(receipt.sum())
        return .result(value: ReceiptEntity(from: receipt),
                       dialog: "Added \(format(price)) of \(taxName). \(receipt.name) now comes to \(total).")
    }
}
