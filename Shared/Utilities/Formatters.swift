import Foundation

func format(_ price: Double) -> String {
    let places = currencyDecimalPlaces()
    let amount = decimal(from: price)
    let currencyCode = defaults.string(forKey: "CurrencySymbol") ?? ""
    if currencyCode == "" {
        return amount.formatted(.number
            .precision(.fractionLength(places))
            .rounded(rule: .toNearestOrAwayFromZero))
    }
    let presentation: CurrencyFormatStyleConfiguration.Presentation =
        defaults.bool(forKey: "UseCurrencyGlyph") ? .narrow : .isoCode
    return amount.formatted(.currency(code: currencyCode)
        .presentation(presentation)
        .precision(.fractionLength(places))
        .rounded(rule: .toNearestOrAwayFromZero))
}

/// Converts via the shortest round-trip representation, so 1.005 becomes exactly 1.005.
func decimal(from value: Double) -> Decimal {
    return Decimal(string: "\(value)", locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
}

func priceFormatStyle() -> FloatingPointFormatStyle<Double> {
    return .number.precision(.fractionLength(0...currencyDecimalPlaces()))
}

/// Whether the currency has a symbol distinct from its ISO code (e.g. ¥ for JPY).
func currencyHasSymbol(_ currencyCode: String) -> Bool {
    let narrow = Decimal.zero.formatted(.currency(code: currencyCode).presentation(.narrow))
    return !narrow.contains(currencyCode)
}

/// The DecimalPlaces setting: 0-3, or `automaticDecimalPlaces` to follow the currency.
let automaticDecimalPlaces = -1

func decimalPlacesSetting() -> Int {
    if defaults.object(forKey: "DecimalPlaces") != nil {
        let places = defaults.integer(forKey: "DecimalPlaces")
        return places < 0 ? automaticDecimalPlaces : min(places, 3)
    }
    // Fall back to the legacy show/hide decimals toggle
    if defaults.object(forKey: "ShowDecimals") != nil && !defaults.bool(forKey: "ShowDecimals") {
        return 0
    }
    return automaticDecimalPlaces
}

func currencyDecimalPlaces() -> Int {
    let setting = decimalPlacesSetting()
    if setting != automaticDecimalPlaces {
        return setting
    }
    let currencyCode = defaults.string(forKey: "CurrencySymbol") ?? ""
    if currencyCode != "" {
        return minorUnits(of: currencyCode)
    }
    if let localCurrencyCode = Locale.current.currency?.identifier {
        return minorUnits(of: localCurrencyCode)
    }
    return 2
}

private let minorUnitsCache = NSCache<NSString, NSNumber>()

/// The number of decimal places the currency uses (e.g. 2 for USD, 0 for JPY).
func minorUnits(of currencyCode: String) -> Int {
    if let cached = minorUnitsCache.object(forKey: currencyCode as NSString) {
        return cached.intValue
    }
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode
    let places = min(max(formatter.maximumFractionDigits, 0), 3)
    minorUnitsCache.setObject(NSNumber(value: places), forKey: currencyCode as NSString)
    return places
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
