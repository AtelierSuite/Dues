import Testing
@testable import Meloan

struct AutoChargesTests {

    private func charges(serviceCharge: Bool = false, country: String = "", rate: Double = 0.0,
                         taxAboveServiceCharge: Bool = false, sumOfItems: Double = 100.0,
                         hasManualTax: Bool = false) -> AutoCharges {
        AutoCharges(addServiceCharge: serviceCharge, taxRateCountry: country, taxRate: rate,
                    taxAboveServiceCharge: taxAboveServiceCharge, sumOfItems: sumOfItems,
                    hasManualTax: hasManualTax)
    }

    @Test func noSettingsAddsNothing() {
        let result = charges(rate: 0.08)
        #expect(result.serviceCharge == nil)
        #expect(result.tax == nil)
    }

    @Test func serviceChargeIsTenPercentOfItems() {
        let result = charges(serviceCharge: true, sumOfItems: 85.0)
        #expect(isClose(result.serviceCharge, 8.5))
        #expect(result.tax == nil)
    }

    @Test func taxIsRateTimesItems() {
        let result = charges(country: "SG", rate: 0.09, sumOfItems: 200.0)
        #expect(result.serviceCharge == nil)
        #expect(isClose(result.tax, 18.0))
    }

    @Test func taxIgnoresServiceChargeByDefault() {
        let result = charges(serviceCharge: true, country: "SG", rate: 0.09, sumOfItems: 100.0)
        #expect(isClose(result.serviceCharge, 10.0))
        #expect(isClose(result.tax, 9.0))
    }

    @Test func taxAboveServiceChargeTaxesTheServiceCharge() {
        let result = charges(serviceCharge: true, country: "SG", rate: 0.09,
                             taxAboveServiceCharge: true, sumOfItems: 100.0)
        #expect(isClose(result.serviceCharge, 10.0))
        // 9% of (100 + 10)
        #expect(isClose(result.tax, 9.9))
    }

    @Test func taxAboveServiceChargeWithoutServiceChargeTaxesItemsOnly() {
        let result = charges(country: "SG", rate: 0.09, taxAboveServiceCharge: true, sumOfItems: 100.0)
        #expect(result.serviceCharge == nil)
        #expect(isClose(result.tax, 9.0))
    }

    @Test func manualTaxSuppressesAutomaticCharges() {
        let result = charges(serviceCharge: true, country: "SG", rate: 0.09,
                             taxAboveServiceCharge: true, hasManualTax: true)
        #expect(result.serviceCharge == nil)
        #expect(result.tax == nil)
    }

    @Test func zeroItemsGivesZeroCharges() {
        let result = charges(serviceCharge: true, country: "JP", rate: 0.1, sumOfItems: 0.0)
        #expect(isClose(result.serviceCharge, 0.0))
        #expect(isClose(result.tax, 0.0))
    }

    @Test func automaticIDsAreRecognised() {
        #expect(AutoCharges.taxID(for: "abc") == "AUTOTAX-abc")
        #expect(AutoCharges.serviceChargeID(for: "abc") == "AUTOTEN-abc")
        #expect(AutoCharges.isAutomatic(taxItemID: AutoCharges.taxID(for: "abc")))
        #expect(AutoCharges.isAutomatic(taxItemID: AutoCharges.serviceChargeID(for: "abc")))
        #expect(!AutoCharges.isAutomatic(taxItemID: "8F3C2A10-0000-0000-0000-000000000000"))
    }
}

struct ApplyAutoChargesTests {

    private func settings(serviceCharge: Bool = false, country: String = "", rate: Double = 0.0,
                          type: String = "") -> AutoCharges.Settings {
        AutoCharges.Settings(addServiceCharge: serviceCharge, taxRateCountry: country, taxRate: rate,
                             taxRateType: type, taxAboveServiceCharge: false)
    }

    private func lunch() throws -> (InMemoryStore, Receipt) {
        let store = try InMemoryStore()
        let receipt = Receipt(name: "Lunch")
        store.context.insert(receipt)
        receipt.addReceiptItems(from: [ReceiptItem(name: "Ramen", price: 100.0, amount: 1)])
        return (store, receipt)
    }

    @Test func addsServiceChargeAndTaxLines() throws {
        let (store, receipt) = try lunch()
        receipt.applyAutoCharges(settings(serviceCharge: true, country: "SG", rate: 0.09, type: "gst"),
                                 in: store.context)
        let serviceCharge = receipt.taxItems?.first { $0.id == AutoCharges.serviceChargeID(for: receipt.id) }
        let tax = receipt.taxItems?.first { $0.id == AutoCharges.taxID(for: receipt.id) }
        #expect(isClose(serviceCharge?.price, 10.0))
        #expect(isClose(tax?.price, 9.0))
    }

    @Test func updatesLinesInPlaceWhenItemsChange() throws {
        let (store, receipt) = try lunch()
        let taxSettings = settings(country: "SG", rate: 0.09)
        receipt.applyAutoCharges(taxSettings, in: store.context)
        receipt.addReceiptItems(from: [ReceiptItem(name: "Gyoza", price: 100.0, amount: 1)])
        receipt.applyAutoCharges(taxSettings, in: store.context)
        #expect(receipt.taxItems?.count == 1)
        #expect(isClose(receipt.sumOfTax(), 18.0))
    }

    @Test func manualTaxRemovesAutomaticLines() throws {
        let (store, receipt) = try lunch()
        let taxSettings = settings(serviceCharge: true, country: "SG", rate: 0.09)
        receipt.applyAutoCharges(taxSettings, in: store.context)
        receipt.addTaxItems(from: [TaxItem(name: "Tax", price: 5.0)])
        #expect(receipt.hasManualTax)
        receipt.applyAutoCharges(taxSettings, in: store.context)
        #expect(receipt.taxItems?.count == 1)
        #expect(isClose(receipt.sumOfTax(), 5.0))
    }

    @Test func tipDoesNotCountAsManualTax() throws {
        let (store, receipt) = try lunch()
        let tip = TaxItem(name: "Tip", price: 5.0)
        tip.id = Gratuity.idPrefix + "1"
        receipt.addTaxItems(from: [tip])
        #expect(!receipt.hasManualTax)
        receipt.applyAutoCharges(settings(country: "SG", rate: 0.09), in: store.context)
        #expect(isClose(receipt.sumOfTax(), 14.0))
    }
}
