import Foundation

/// The automatic service charge and tax that `ReceiptEditor` adds on save, computed from the
/// user's settings. Kept free of SwiftData and SwiftUI so it can be unit tested.
struct AutoCharges {

    static let taxIDPrefix = "AUTOTAX-"
    static let serviceChargeIDPrefix = "AUTOTEN-"
    static let serviceChargeRate = 0.1

    /// The service charge amount, or `nil` when no automatic service charge should exist.
    let serviceCharge: Double?
    /// The tax amount, or `nil` when no automatic tax should exist.
    let tax: Double?

    init(addServiceCharge: Bool, taxRateCountry: String, taxRate: Double, taxAboveServiceCharge: Bool,
         sumOfItems: Double, hasManualTax: Bool) {
        // Auto charges are suppressed when the user supplied their own tax (no double tax).
        // Calculate service charge first (needed for tax-above-service-charge)
        let serviceChargeAmount: Double
        if addServiceCharge && !hasManualTax {
            serviceChargeAmount = sumOfItems * AutoCharges.serviceChargeRate
            serviceCharge = serviceChargeAmount
        } else {
            serviceChargeAmount = 0.0
            serviceCharge = nil
        }
        if taxRateCountry != "" && !hasManualTax {
            let taxBase: Double
            if taxAboveServiceCharge && addServiceCharge {
                taxBase = sumOfItems + serviceChargeAmount
            } else {
                taxBase = sumOfItems
            }
            tax = taxBase * taxRate
        } else {
            tax = nil
        }
    }

    /// Whether a tax item was added automatically rather than entered by the user.
    static func isAutomatic(taxItemID id: String) -> Bool {
        id.hasPrefix(taxIDPrefix) || id.hasPrefix(serviceChargeIDPrefix)
    }

    static func taxID(for receiptID: String) -> String {
        taxIDPrefix + receiptID
    }

    static func serviceChargeID(for receiptID: String) -> String {
        serviceChargeIDPrefix + receiptID
    }
}
