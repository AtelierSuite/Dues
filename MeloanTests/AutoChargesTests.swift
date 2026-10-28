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
