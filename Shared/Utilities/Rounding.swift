import Foundation

// Warikan-style rounding: each borrower's share of a receipt is rounded up to the chosen unit,
// and the difference goes to the person who paid. Rounding is display-only; stored amounts and
// sumOwed(to:for:) stay unrounded.

let shareRoundingUnits: [Int] = [1, 10, 100]

func shareRoundingUnit() -> Int {
    let unit = defaults.integer(forKey: "ShareRounding")
    return shareRoundingUnits.contains(unit) ? unit : 0
}

func roundUpShare(_ amount: Double) -> Double {
    let unit = Double(shareRoundingUnit())
    // Settled or zero shares stay as they are.
    guard unit > 0, amount > 0.000_001 else { return amount }
    // Tolerate floating-point noise so exact multiples (e.g. 1000.0000001) don't round up a whole unit.
    return (amount / unit - 0.000_001).rounded(.up) * unit
}

extension Receipt {
    func roundedSumOwed(to lender: Person, for borrower: Person) -> Double {
        return roundUpShare(sumOwed(to: lender, for: borrower))
    }

    /// The total rounding difference across all borrowers of this receipt, which goes to the payer.
    func roundingDifference() -> Double {
        guard let personWhoPaid = personWhoPaid else { return .zero }
        return borrowers().reduce(0.0) { partial, borrower in
            let owed = sumOwed(to: personWhoPaid, for: borrower)
            return partial + roundUpShare(owed) - owed
        }
    }
}

extension Person {
    func roundedSumOwed(to personWhoPaid: Person?) -> Double {
        guard let personWhoPaid = personWhoPaid else { return .zero }
        var sum: Double = .zero
        for receipt in receiptsParticipated ?? [] where receipt.personWhoPaid == personWhoPaid {
            sum += receipt.roundedSumOwed(to: personWhoPaid, for: self)
        }
        return sum
    }

    /// How much of roundedSumOwed(to:) comes from rounding up this person's shares.
    func roundingDifference(to personWhoPaid: Person?) -> Double {
        return roundedSumOwed(to: personWhoPaid) - sumOwed(to: personWhoPaid)
    }
}

/// Whether a rounding difference is large enough to show.
func isVisibleRounding(_ difference: Double) -> Bool {
    return difference > 0.000_1
}
