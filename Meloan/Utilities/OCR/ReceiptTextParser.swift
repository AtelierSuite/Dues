import Foundation

enum ReceiptTextParser {

    /// Mutable accumulator threaded through line processing.
    private final class Accumulator {
        var items: [ParsedReceiptItem] = []
        var taxes: [ParsedAdjustment] = []
        var discounts: [ParsedAdjustment] = []
    }

    // MARK: - Public API

    static func parse(lines rawLines: [String]) -> ParsedReceipt {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let accumulator = Accumulator()
        for line in lines {
            process(line: line, into: accumulator)
        }

        return ParsedReceipt(
            merchantName: detectMerchantName(in: lines),
            items: accumulator.items,
            taxes: accumulator.taxes,
            discounts: accumulator.discounts
        )
    }

    private static func process(line: String, into accumulator: Accumulator) {
        // Skip obvious non-amount metadata (dates, times, phone numbers).
        if looksLikeDateOrPhone(line) { return }
        // No price on this line — header / address / note. Not an item.
        guard let amount = extractTrailingAmount(from: line) else { return }

        let label = labelPortion(of: line, removingAmount: amount.matchedText)
        switch classify(line: line, label: label, amount: amount.value) {
        case .ignore, .subtotal, .total:
            // Subtotal/total lines are classified only so they never become items.
            return
        case .tax where abs(amount.value) > 0:
            accumulator.taxes.append(ParsedAdjustment(name: cleanedLabel(label, fallback: "Tax"),
                                                      price: abs(amount.value)))
        case .discount where abs(amount.value) > 0:
            accumulator.discounts.append(ParsedAdjustment(name: cleanedLabel(label, fallback: "Discount"),
                                                          price: abs(amount.value)))
        case .item:
            let (name, quantity) = nameAndQuantity(from: label)
            guard !name.isEmpty, amount.value > 0 else { return }
            accumulator.items.append(ParsedReceiptItem(name: name, price: amount.value,
                                                       quantity: max(quantity, 1)))
        default:
            return
        }
    }

    // MARK: - Amount extraction

    /// Finds the right-most monetary amount in a line and returns its value.
    static func extractTrailingAmount(from line: String) -> ParsedAmount? {
        let pattern = #"[-(]?\s*(?:[$€£¥₫₱฿₩]|RM|Rp|S\$|HK\$|NT\$|kr|zł|Kč|Ft|лв|руб)?\s*\d[\d.,]*\d|\d"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsLine = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsLine.length))
        guard !matches.isEmpty else { return nil }

        // Walk candidates from the right; accept the first that parses to a plausible amount.
        for match in matches.reversed() {
            let raw = nsLine.substring(with: match.range)
            // Surrounding context for sign detection (parentheses / trailing minus).
            let tail = trailingContext(of: nsLine, after: match.range)
            let negative = raw.contains("(") || raw.hasPrefix("-") || tail.hasPrefix(")") || tail.hasPrefix("-")
            guard let value = normalizeAmount(raw) else { continue }
            // Reject percentages ("8%") and bare small integers that are likely quantities/codes.
            if tail.hasPrefix("%") { continue }
            if !raw.contains(".") && !raw.contains(",") && !containsCurrencySymbol(raw) {
                continue
            }
            return ParsedAmount(value: negative ? -abs(value) : value, matchedText: raw)
        }

        // Fallback: a lone integer at the end (e.g. whole-number currencies like JPY/VND/IDR).
        if let last = matches.last {
            let raw = nsLine.substring(with: last.range)
            // Require at least two digits: a single stray digit is far more likely a
            // quantity, line count, or code (e.g. "Latte x 2", "Table 5") than a price.
            let digitCount = raw.filter { $0.isNumber }.count
            if let value = normalizeAmount(raw), value >= 1, digitCount >= 2 {
                let tail = trailingContext(of: nsLine, after: last.range)
                if tail.hasPrefix("%") { return nil }
                let negative = raw.hasPrefix("-") || tail.hasPrefix(")") || tail.hasPrefix("-")
                return ParsedAmount(value: negative ? -abs(value) : value, matchedText: raw)
            }
        }
        return nil
    }

    /// Converts a raw monetary token (any locale grouping) into a Double.
    static func normalizeAmount(_ raw: String) -> Double? {
        // Strip everything except digits and separators.
        var token = raw
        for symbol in ["RM", "Rp", "S$", "HK$", "NT$", "kr", "zł", "Kč", "Ft", "лв", "руб"] {
            token = token.replacingOccurrences(of: symbol, with: "")
        }
        token = token.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !token.isEmpty else { return nil }

        let hasDot = token.contains(".")
        let hasComma = token.contains(",")

        if hasDot && hasComma {
            // The right-most separator is the decimal point; the other groups thousands.
            if let lastDot = token.lastIndex(of: "."), let lastComma = token.lastIndex(of: ",") {
                if lastComma > lastDot {
                    // European: 1.234,56
                    token = token.replacingOccurrences(of: ".", with: "")
                    token = token.replacingOccurrences(of: ",", with: ".")
                } else {
                    // US/UK: 1,234.56
                    token = token.replacingOccurrences(of: ",", with: "")
                }
            }
        } else if hasComma {
            token = disambiguateSingleSeparator(token, separator: ",")
        } else if hasDot {
            token = disambiguateSingleSeparator(token, separator: ".")
        }

        return Double(token)
    }

    /// Resolves whether a single repeated separator is a decimal or thousands grouping.
    private static func disambiguateSingleSeparator(_ token: String, separator: Character) -> String {
        let parts = token.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        if parts.count == 2 {
            let fraction = parts[1]
            if fraction.count == 2 {
                // Decimal separator (e.g. 12,50 or 12.50).
                return parts[0] + "." + parts[1]
            }
            if fraction.count == 3 {
                // Thousands grouping (e.g. 25,000 / 25.000 — whole-number currencies).
                return parts[0] + parts[1]
            }
            // 1 or >3 fraction digits → treat as decimal.
            return parts[0] + "." + parts[1]
        }
        // Multiple separators of one kind → all thousands groupings.
        return parts.joined()
    }

    private static func containsCurrencySymbol(_ token: String) -> Bool {
        token.contains { "$€£¥₫₱฿₩".contains($0) }
            || ["RM", "Rp", "S$", "kr", "zł", "Kč", "Ft"].contains { token.contains($0) }
    }

    private static func trailingContext(of nsLine: NSString, after range: NSRange) -> String {
        let end = range.location + range.length
        guard end < nsLine.length else { return "" }
        let rest = nsLine.substring(from: end)
        return rest.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Classification

    static func classify(line: String, label: String, amount: Double) -> LineCategory {
        let haystack = fold(line)

        // Tax-breakdown info lines (e.g. "VATable Sales") must never be charged.
        if containsAny(haystack, in: Keywords.informational) {
            return .ignore
        }
        if containsAny(haystack, in: Keywords.ignore) && !containsAny(haystack, in: Keywords.tax) {
            return .ignore
        }
        if amount < 0 || containsAny(haystack, in: Keywords.discount) {
            return .discount
        }
        if containsAny(haystack, in: Keywords.tax) {
            return .tax
        }
        if let pct = percentageValue(in: line), pct > 0, pct <= 30,
           !containsAny(haystack, in: Keywords.subtotal), !containsAny(haystack, in: Keywords.total) {
            return .tax
        }
        if containsAny(haystack, in: Keywords.subtotal) {
            return .subtotal
        }
        if containsAny(haystack, in: Keywords.total) {
            return .total
        }
        // An item needs an actual name (letters), not just a stray number.
        if label.contains(where: { $0.isLetter }) {
            return .item
        }
        return .ignore
    }

    // MARK: - Label / name / quantity

    static func labelPortion(of line: String, removingAmount amount: String) -> String {
        guard let range = line.range(of: amount, options: .backwards) else { return line }
        return String(line[line.startIndex..<range.lowerBound])
            .trimmingCharacters(in: CharacterSet(charactersIn: " .,:-•*\t·…"))
    }

    /// Extracts a clean item name and a leading/embedded quantity (e.g. "2 x Latte").
    static func nameAndQuantity(from label: String) -> (name: String, quantity: Int) {
        var working = label
        var quantity = 1

        // Patterns: "2 x Item", "2x Item", "Item x2", "2 @ 1.50".
        let leading = try? NSRegularExpression(pattern: #"^\s*(\d{1,3})\s*[xX×@]\s*"#)
        let trailing = try? NSRegularExpression(pattern: #"\s*[xX×]\s*(\d{1,3})\s*$"#)
        let nsLabel = working as NSString
        let fullRange = NSRange(location: 0, length: nsLabel.length)
        if let match = leading?.firstMatch(in: working, range: fullRange),
           let value = Int(nsLabel.substring(with: match.range(at: 1))) {
            quantity = value
            working = nsLabel.substring(from: match.range.location + match.range.length)
        } else if let match = trailing?.firstMatch(in: working, range: fullRange),
                  let value = Int(nsLabel.substring(with: match.range(at: 1))) {
            quantity = value
            working = nsLabel.substring(to: match.range.location)
        }

        // Drop any leftover unit-price fragment like "@ 1.50".
        if let unitPriceRange = working.range(of: #"\s*@\s*[\d.,]+\s*$"#, options: .regularExpression) {
            working.removeSubrange(unitPriceRange)
        }

        let name = working.trimmingCharacters(in: CharacterSet(charactersIn: " .,:-•*\t·…"))
        return (name, max(quantity, 1))
    }

    private static func cleanedLabel(_ label: String, fallback: String) -> String {
        let trimmed = label.trimmingCharacters(in: CharacterSet(charactersIn: " .,:-•*\t·…"))
        return trimmed.isEmpty ? fallback : trimmed
    }

    // MARK: - Merchant detection

    static func detectMerchantName(in lines: [String]) -> String? {
        for line in lines.prefix(4) {
            if extractTrailingAmount(from: line) != nil { continue }
            if looksLikeDateOrPhone(line) { continue }
            let letters = line.filter { $0.isLetter }
            if letters.count >= 2 && !line.lowercased().contains("http") {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - Heuristics

    /// Returns the percentage value if the line contains one (e.g. "10%", "19,5 %").
    static func percentageValue(in line: String) -> Double? {
        guard let range = line.range(of: #"\d{1,3}(?:[.,]\d+)?\s*%"#, options: .regularExpression) else {
            return nil
        }
        let token = line[range]
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(token)
    }

    static func looksLikeDateOrPhone(_ line: String) -> Bool {
        let patterns = [
            #"\b\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}\b"#,   // date 12/05/2026
            #"\b\d{1,2}:\d{2}(:\d{2})?\b"#,               // time 14:05
            #"\b(?:\+?\d[\d\s\-]{7,})\b(?!\d*[.,]\d{2})"# // phone-ish runs of digits
        ]
        let hasDecimalAmount = line.range(of: #"\d[.,]\d{2}\b"#, options: .regularExpression) != nil
        for pattern in patterns where line.range(of: pattern, options: .regularExpression) != nil {
            if !hasDecimalAmount { return true }
        }
        return false
    }

    // MARK: - Keyword matching

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private static func containsAny(_ haystack: String, in keywords: [String]) -> Bool {
        for keyword in keywords where matchesKeyword(haystack, keyword) {
            return true
        }
        return false
    }

    private static func matchesKeyword(_ haystack: String, _ keyword: String) -> Bool {
        guard keyword.allSatisfy({ $0.isASCII }) else {
            return haystack.contains(keyword)
        }
        let escaped = NSRegularExpression.escapedPattern(for: keyword)
        let pattern = "(?<![a-z])\(escaped)(?![a-z])"
        return haystack.range(of: pattern, options: .regularExpression) != nil
    }
}
