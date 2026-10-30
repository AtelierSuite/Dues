import Foundation

/// Amounts are stored as Double (the CloudKit schema can't change field types), so totals and
/// splits are calculated in integer minor units (e.g. cents) to stay exact and add up.
enum Money {

    static func minorUnits(_ amount: Double, places: Int = currencyDecimalPlaces()) -> Int64 {
        var value = decimal(from: amount) * pow(Decimal(10), places)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func amount(_ minorUnits: Int64, places: Int = currencyDecimalPlaces()) -> Double {
        let value = Decimal(minorUnits) / pow(Decimal(10), places)
        return NSDecimalNumber(decimal: value).doubleValue
    }

    /// Splits `total` proportionally to `weights` so the parts add up to exactly `total`.
    /// Leftover minor units go to the parts with the largest remainders, earliest first.
    static func allocate(_ total: Int64, by weights: [Int64]) -> [Int64] {
        var total = total
        var weights = weights
        var weightSum = weights.reduce(0, +)
        guard weightSum != 0 else { return weights.map { _ in 0 } }
        if weightSum < 0 {
            total = -total
            weights = weights.map { -$0 }
            weightSum = -weightSum
        }
        var parts: [Int64] = []
        var remainders: [Int64] = []
        for weight in weights {
            var (quotient, remainder) = weightSum.dividingFullWidth(total.multipliedFullWidth(by: weight))
            if remainder < 0 {
                quotient -= 1
                remainder += weightSum
            }
            parts.append(quotient)
            remainders.append(remainder)
        }
        let leftover = Int(total - parts.reduce(0, +))
        let order = remainders.indices.sorted { remainders[$0] != remainders[$1] ?
            remainders[$0] > remainders[$1] : $0 < $1 }
        for index in order.prefix(leftover) {
            parts[index] += 1
        }
        return parts
    }

    /// Splits `total` evenly into `count` parts that add up to exactly `total`.
    static func split(_ total: Int64, into count: Int) -> [Int64] {
        return allocate(total, by: Array(repeating: 1, count: count))
    }
}
