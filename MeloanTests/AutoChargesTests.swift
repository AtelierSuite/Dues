import Testing
@testable import Meloan

struct AutoChargesTests {

    @Test func noSettingsAddsNothing() {
        let charges = AutoCharges(addServiceCharge: false, taxRateCountry: "", taxRate: 0.08,
                                  taxAboveServiceCharge: false, sumOfItems: 100.0, hasManualTax: false)
        #expect(charges.serviceCharge == nil)
        #expect(charges.tax == nil)
    }
}
