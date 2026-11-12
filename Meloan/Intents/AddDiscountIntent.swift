import AppIntents
import Foundation

struct AddDiscountIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Discount"
    static var description = IntentDescription(
        "Adds a discount, such as a coupon, to a receipt. It's shared across the items by price.",
        categoryName: "Receipts"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    @Parameter(title: "Value", requestValueDialog: "How much is the discount?")
    var value: Double

    @Parameter(title: "Calculation", default: .amount)
    var calculation: ChargeCalculation

    @Parameter(title: "Name", description: "Leave empty to call it Discount.")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add a discount of \(\.$value) to \(\.$receipt)") {
            \.$calculation
            \.$name
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReceiptEntity> & ProvidesDialog {
        guard value >= 0 else { throw IntentError.negativePrice }
        let receipt = try IntentStore.receipt(self.receipt)
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let discountName = trimmedName.isEmpty ? String(localized: "Discount") : trimmedName
        let price = calculation.price(for: value, itemsTotal: receipt.sumOfItems())

        receipt.addDiscountItems(from: [DiscountItem(name: discountName, price: price)])
        receipt.applyAutoCharges(in: IntentStore.context)
        try IntentStore.save()

        let total = format(receipt.sum())
        return .result(value: ReceiptEntity(from: receipt),
                       dialog: "Added \(format(price)) off for \(discountName). \(receipt.name) now comes to \(total).")
    }
}
