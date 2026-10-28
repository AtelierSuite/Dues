import Foundation

/// A tip is stored as an ordinary `TaxItem` whose id starts with `Gratuity.idPrefix`, so it is
/// split by share through `Receipt.overallRate()` with no model change. The prefix lets the
/// editor tell a tip apart from a user-entered tax line: a tip must not count as manual tax,
/// which would switch off the automatic tax and service charge.
///
/// The tip is a flat amount worked out when it is added. It does not follow later item
/// edits; adding a tip again replaces the existing one.
enum Gratuity {

    struct RoundUpOption: Hashable {
        let target: Double
        let tip: Double
    }

    static let idPrefix = "TIP-"
    static let presetPercentages: [Double] = [10, 15, 18, 20]

    static func isTip(id: String) -> Bool {
        id.hasPrefix(idPrefix)
    }

    /// `percentage` (e.g. 15 for 15%) of `base`, rounded to the displayed decimal places.
    static func amount(percentage: Double, of base: Double) -> Double {
        roundedToCurrency(max(0.0, base) * percentage / 100.0)
    }

    /// Round-up steps of 1, 5 and 10, scaled up for currencies whose units are too
    /// small for rounding to 1, 5 or 10 to make sense (¥10 or 10₫ is not a tip).
    static func roundUpSteps(currencyCode: String) -> [Double] {
        let scale: Double
        switch currencyCode {
        case "IDR", "KHR", "LAK", "VND": scale = 1000
        case "HUF", "ISK", "JPY", "MMK": scale = 100
        case "ALL", "CZK", "MKD", "MXN", "PHP", "RSD", "THB", "TRY", "UAH": scale = 10
        default: scale = 1
        }
        return [1, 5, 10].map { $0 * scale }
    }

    /// One option per step that rounds `total` up to a different amount. Steps that the
    /// total is already a multiple of are skipped, since they would add no tip.
    static func roundUpOptions(total: Double, currencyCode: String) -> [RoundUpOption] {
        let total = roundedToCurrency(total)
        guard total > 0 else { return [] }
        var options: [RoundUpOption] = []
        for step in roundUpSteps(currencyCode: currencyCode) {
            // The epsilon keeps an exact multiple (stored as 49.999…) from rounding up a whole step.
            let target = ((total / step) - 1e-9).rounded(.up) * step
            let tip = roundedToCurrency(target - total)
            if tip > 0 && !options.contains(where: { $0.target == target }) {
                options.append(RoundUpOption(target: target, tip: tip))
            }
        }
        return options
    }

    static func roundedToCurrency(_ value: Double) -> Double {
        let factor = pow(10.0, Double(currencyDecimalPlaces()))
        return (value * factor).rounded() / factor
    }
}
