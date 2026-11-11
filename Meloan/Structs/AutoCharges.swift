import Foundation
import SwiftData

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

extension AutoCharges {

    /// The user's automatic tax and service charge settings, from More > Automatic Tax Rates.
    struct Settings {
        var addServiceCharge: Bool
        var taxRateCountry: String
        var taxRate: Double
        var taxRateType: String
        var taxAboveServiceCharge: Bool

        static var current: Settings {
            Settings(addServiceCharge: defaults.bool(forKey: "AddTenPercent"),
                     taxRateCountry: defaults.string(forKey: "TaxRateCountry") ?? "",
                     taxRate: defaults.double(forKey: "TaxRate"),
                     taxRateType: defaults.string(forKey: "TaxRateType") ?? "",
                     taxAboveServiceCharge: defaults.bool(forKey: "TaxAboveServiceCharge"))
        }

        var isConfigured: Bool {
            addServiceCharge || taxRateCountry != ""
        }
    }

    init(settings: Settings, sumOfItems: Double, hasManualTax: Bool) {
        self.init(addServiceCharge: settings.addServiceCharge, taxRateCountry: settings.taxRateCountry,
                  taxRate: settings.taxRate, taxAboveServiceCharge: settings.taxAboveServiceCharge,
                  sumOfItems: sumOfItems, hasManualTax: hasManualTax)
    }

    /// Whether a tax item was entered by the user, rather than added automatically or as a tip.
    static func isManual(taxItemID id: String) -> Bool {
        !isAutomatic(taxItemID: id) && !Gratuity.isTip(id: id)
    }
}

extension Receipt {

    var hasManualTax: Bool {
        taxItems?.contains(where: { AutoCharges.isManual(taxItemID: $0.id) }) ?? false
    }

    /// Adds, updates or removes the automatic service charge and tax lines so they match the
    /// receipt's items and the user's settings. Does not save.
    func applyAutoCharges(_ settings: AutoCharges.Settings = .current, in modelContext: ModelContext) {
        // Auto charges are suppressed when the user supplied their own tax (no double tax).
        let autoCharges = AutoCharges(settings: settings, sumOfItems: sumOfItems(), hasManualTax: hasManualTax)
        let serviceChargeID = AutoCharges.serviceChargeID(for: id)
        if let serviceChargeAmount = autoCharges.serviceCharge {
            if let serviceChargeItem = taxItems?.first(where: { $0.id == serviceChargeID }) {
                serviceChargeItem.price = serviceChargeAmount
            } else {
                let automaticServiceCharge = TaxItem(name: NSLocalizedString("Receipt.ServiceCharge", comment: ""),
                                                     price: serviceChargeAmount)
                automaticServiceCharge.id = serviceChargeID
                addTaxItems(from: [automaticServiceCharge])
            }
        } else {
            // Service charge off, or the user supplied their own — remove any stale auto item.
            removeTaxItem(withID: serviceChargeID, in: modelContext)
        }
        let taxID = AutoCharges.taxID(for: id)
        if let taxAmount = autoCharges.tax {
            if let taxItem = taxItems?.first(where: { $0.id == taxID }) {
                taxItem.price = taxAmount
            } else {
                let automaticTaxItem = TaxItem(name: "", price: taxAmount)
                automaticTaxItem.id = taxID
                switch settings.taxRateType {
                case "gst":
                    automaticTaxItem.name = NSLocalizedString("Receipt.Tax.GST", comment: "")
                case "vat":
                    automaticTaxItem.name = NSLocalizedString("Receipt.Tax.VAT", comment: "")
                default:
                    automaticTaxItem.name = ""
                }
                addTaxItems(from: [automaticTaxItem])
            }
        } else {
            // Tax region cleared, or the user provided their own tax — drop the auto item.
            removeTaxItem(withID: taxID, in: modelContext)
        }
    }

    func removeTaxItem(withID id: String, in modelContext: ModelContext) {
        guard let item = taxItems?.first(where: { $0.id == id }) else { return }
        taxItems?.removeAll { $0.id == id }
        modelContext.delete(item)
    }
}
