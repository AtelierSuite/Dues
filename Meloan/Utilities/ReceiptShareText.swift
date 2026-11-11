import Foundation
import SwiftData

extension Receipt {

    /// The receipt as plain text, for sharing from the receipt and the Get Receipt Text intent.
    func shareText() -> String {
        var lines: [String] = []
        lines.append(name)
        lines.append(String(repeating: "-", count: 30))
        if let personWhoPaid = personWhoPaid {
            lines.append("\(NSLocalizedString("Receipt.Payer", comment: "")): \(personWhoPaid.name)")
            lines.append("")
        }
        let items = self.items()
        let discountItems = self.discountItems()
        let taxItems = self.taxItems()
        let totals = self.totals()
        if !items.isEmpty {
            lines.append(NSLocalizedString("Receipt.PurchasedItems", comment: ""))
            for item in items {
                let assignee = item.person?.name ?? NSLocalizedString("Shared.Shared", comment: "")
                lines.append("  \(item.name) - \(format(item.price)) [\(assignee)]")
            }
            lines.append("")
        }
        if !discountItems.isEmpty {
            lines.append(NSLocalizedString("Receipt.Discounts", comment: ""))
            for item in discountItems {
                lines.append("  \(item.name) - \(format(item.price))")
            }
            lines.append("")
        }
        if !taxItems.isEmpty {
            lines.append(NSLocalizedString("Receipt.Taxes", comment: ""))
            for item in taxItems {
                lines.append("  \(item.name) - \(format(item.price))")
            }
            lines.append("")
        }
        lines.append(String(repeating: "-", count: 30))
        lines.append("\(NSLocalizedString("Receipt.Total.BeforeTax", comment: "")): \(format(totals.items))")
        lines.append("\(NSLocalizedString("Receipt.Total.AfterTax", comment: "")): \(format(totals.total))")
        return lines.joined(separator: "\n")
    }
}
