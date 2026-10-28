import Foundation

struct CurrencyGlyph {
    let symbol: String
    let isSuffix: Bool
}

let currencyGlyphs: [String: CurrencyGlyph] = [
    "AUD": CurrencyGlyph(symbol: "$", isSuffix: false),
    "BGN": CurrencyGlyph(symbol: "лв", isSuffix: true),
    "BND": CurrencyGlyph(symbol: "$", isSuffix: false),
    "BRL": CurrencyGlyph(symbol: "R$", isSuffix: false),
    "CAD": CurrencyGlyph(symbol: "$", isSuffix: false),
    "CZK": CurrencyGlyph(symbol: "Kč", isSuffix: true),
    "DKK": CurrencyGlyph(symbol: "kr", isSuffix: true),
    "EUR": CurrencyGlyph(symbol: "€", isSuffix: false),
    "GBP": CurrencyGlyph(symbol: "£", isSuffix: false),
    "HUF": CurrencyGlyph(symbol: "Ft", isSuffix: true),
    "IDR": CurrencyGlyph(symbol: "Rp", isSuffix: false),
    "INR": CurrencyGlyph(symbol: "₹", isSuffix: false),
    "ISK": CurrencyGlyph(symbol: "kr", isSuffix: true),
    "JPY": CurrencyGlyph(symbol: "¥", isSuffix: false),
    "KHR": CurrencyGlyph(symbol: "៛", isSuffix: true),
    "LAK": CurrencyGlyph(symbol: "₭", isSuffix: false),
    "MXN": CurrencyGlyph(symbol: "$", isSuffix: false),
    "MYR": CurrencyGlyph(symbol: "RM", isSuffix: false),
    "NOK": CurrencyGlyph(symbol: "kr", isSuffix: true),
    "PHP": CurrencyGlyph(symbol: "₱", isSuffix: false),
    "PLN": CurrencyGlyph(symbol: "zł", isSuffix: true),
    "RON": CurrencyGlyph(symbol: "lei", isSuffix: true),
    "SEK": CurrencyGlyph(symbol: "kr", isSuffix: true),
    "SGD": CurrencyGlyph(symbol: "$", isSuffix: false),
    "THB": CurrencyGlyph(symbol: "฿", isSuffix: false),
    "TRY": CurrencyGlyph(symbol: "₺", isSuffix: false),
    "UAH": CurrencyGlyph(symbol: "₴", isSuffix: false),
    "USD": CurrencyGlyph(symbol: "$", isSuffix: false),
    "VND": CurrencyGlyph(symbol: "₫", isSuffix: true)
]

func format(_ price: Double) -> String {
    let currencySymbol = defaults.string(forKey: "CurrencySymbol") ?? ""
    let amount = String(format: "%.\(currencyDecimalPlaces())f", price)
    if currencySymbol == "" {
        return amount
    }
    if defaults.bool(forKey: "UseCurrencyGlyph"), let glyph = currencyGlyphs[currencySymbol] {
        return glyph.isSuffix ? "\(amount) \(glyph.symbol)" : "\(glyph.symbol) \(amount)"
    }
    return "\(currencySymbol) \(amount)"
}

func priceFormatStyle() -> FloatingPointFormatStyle<Double> {
    return .number.precision(.fractionLength(0...currencyDecimalPlaces()))
}

func currencyDecimalPlaces() -> Int {
    if defaults.object(forKey: "DecimalPlaces") != nil {
        return min(max(defaults.integer(forKey: "DecimalPlaces"), 0), 3)
    }
    // Fall back to the legacy show/hide decimals toggle
    if defaults.object(forKey: "ShowDecimals") != nil && !defaults.bool(forKey: "ShowDecimals") {
        return 0
    }
    return 2
}

func hey(_ person: Person, youOweMe price: Double) -> String {
    let localizedText = NSLocalizedString("IOU.ShareText", comment: "")
    return localizedText
        .replacingOccurrences(of: "%1", with: person.name)
        .replacingOccurrences(of: "%2", with: format(price))
}

func countryName(for countryCode: String) -> String {
    let langCode = Locale.preferredLanguages[0]
    let current = Locale(identifier: langCode)
    if countryCode.contains("-") {
        return NSLocalizedString("State.\(countryCode)", comment: "")
    } else {
        return current.localizedString(forRegionCode: countryCode) ?? countryCode
    }
}
