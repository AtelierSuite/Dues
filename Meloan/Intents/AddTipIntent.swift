import AppIntents
import Foundation

enum TipMethod: String, AppEnum {
    case percentage
    case roundUp

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tip Method")
    static var caseDisplayRepresentations: [TipMethod: DisplayRepresentation] = [
        .percentage: "Percentage",
        .roundUp: "Round Up"
    ]
}

struct AddTipIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Tip"
    static var description = IntentDescription(
        "Adds a tip by percentage or by rounding the total up, replacing any tip already there.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    @Parameter(title: "Method", default: .percentage)
    var method: TipMethod

    @Parameter(title: "Percentage", description: "The tip as a percentage of the items, less discounts.",
               default: 15, inclusiveRange: (0.1, 100))
    var percentage: Double

    @Parameter(title: "Round Up To",
               description: "The total to round up to. Leave empty to round up to the next whole amount.")
    var roundUpTarget: Double?

    static var parameterSummary: some ParameterSummary {
        Switch(\.$method) {
            Case(.roundUp) {
                Summary("Add a tip to \(\.$receipt) by \(\.$method)") {
                    \.$roundUpTarget
                }
            }
            DefaultCase {
                Summary("Add a \(\.$percentage)% tip to \(\.$receipt)") {
                    \.$method
                }
            }
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        let receipt = try IntentStore.receipt(self.receipt)
        let existingTip = receipt.taxItems?.first { Gratuity.isTip(id: $0.id) }
        // Bring the automatic charges up to date first, so rounding up lands on the real total.
        receipt.applyAutoCharges(in: IntentStore.context)
        let totalBeforeTip = receipt.sum() - (existingTip?.price ?? .zero)

        let amount: Double
        switch method {
        case .percentage:
            amount = Gratuity.amount(percentage: percentage,
                                     of: receipt.sumOfItems() - receipt.sumOfDiscount())
        case .roundUp:
            if let roundUpTarget {
                amount = roundUpTarget - totalBeforeTip
            } else {
                let currencyCode = defaults.string(forKey: "CurrencySymbol") ?? ""
                amount = Gratuity.roundUpOptions(total: totalBeforeTip, currencyCode: currencyCode)
                    .first?.tip ?? .zero
            }
        }
        guard Gratuity.roundedToCurrency(amount) > 0 else { throw IntentError.noTipToAdd }

        // One tip per receipt: tipping again updates the existing line, keeping its name.
        if let existingTip {
            existingTip.price = amount
        } else {
            let tip = TaxItem(name: NSLocalizedString("Receipt.Tip", comment: ""), price: amount)
            tip.id = Gratuity.idPrefix + UUID().uuidString
            receipt.addTaxItems(from: [tip])
        }
        try IntentStore.save()

        return .result(value: ReceiptEntity(from: receipt),
                       dialog: "Added a \(format(amount)) tip. \(receipt.name) now comes to \(format(receipt.sum())).")
    }
}
