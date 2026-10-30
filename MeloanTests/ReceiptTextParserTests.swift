import Testing
@testable import Meloan

struct ReceiptTextParserTests {

    @Test func emptyInputParsesToAnEmptyReceipt() {
        let parsed = ReceiptTextParser.parse(lines: ["", "   ", "\n"])
        #expect(parsed.isEmpty)
        #expect(parsed.merchantName == nil)
    }

    @Test func parsesATypicalReceipt() {
        let parsed = ReceiptTextParser.parse(lines: [
            "Joe's Diner",
            "123 Main St",
            "12/05/2026 14:05",
            "2 x Latte 9.00",
            "Bagel 3.50",
            "Subtotal 12.50",
            "Tax 8% 1.00",
            "Discount -2.00",
            "Total 11.50",
            "Visa 11.50",
            "Thank you!"
        ])
        #expect(parsed.merchantName == "Joe's Diner")
        #expect(parsed.items == [
            ParsedReceiptItem(name: "Latte", price: 9.0, quantity: 2),
            ParsedReceiptItem(name: "Bagel", price: 3.5, quantity: 1)
        ])
        #expect(parsed.taxes == [ParsedAdjustment(name: "Tax 8%", price: 1.0)])
        #expect(parsed.discounts == [ParsedAdjustment(name: "Discount", price: 2.0)])
    }

    @Test func parsesEuropeanDecimalCommas() {
        let parsed = ReceiptTextParser.parse(lines: [
            "Bäckerei Müller",
            "Kaffee 3,50",
            "Brot 1.234,56",
            "MwSt 19% 0,67",
            "Summe 1.238,73"
        ])
        #expect(parsed.merchantName == "Bäckerei Müller")
        #expect(parsed.items == [
            ParsedReceiptItem(name: "Kaffee", price: 3.5, quantity: 1),
            ParsedReceiptItem(name: "Brot", price: 1234.56, quantity: 1)
        ])
        #expect(parsed.taxes == [ParsedAdjustment(name: "MwSt 19%", price: 0.67)])
        #expect(parsed.discounts.isEmpty)
    }

    @Test func parsesWholeNumberCurrencies() {
        let parsed = ReceiptTextParser.parse(lines: [
            "Pho Bo 65.000",
            "Banh Mi 25,000",
            "Ramen 980",
            "Tong cong 1.070.980"
        ])
        #expect(parsed.items == [
            ParsedReceiptItem(name: "Pho Bo", price: 65000, quantity: 1),
            ParsedReceiptItem(name: "Banh Mi", price: 25000, quantity: 1),
            ParsedReceiptItem(name: "Ramen", price: 980, quantity: 1)
        ])
    }

    @Test func ignoresStrayQuantitiesAndCodes() {
        let parsed = ReceiptTextParser.parse(lines: [
            "Latte x 2",
            "Table 5",
            "Rechnung Nr. 4711",
            "Cash 20.00",
            "Change 8.50"
        ])
        #expect(parsed.items.isEmpty)
        #expect(parsed.taxes.isEmpty)
        #expect(parsed.discounts.isEmpty)
    }

    @Test func classifiesServiceChargeAsTaxAndIgnoresTaxBreakdownLines() {
        let parsed = ReceiptTextParser.parse(lines: [
            "Adobo 250.00",
            "VATable Sales 223.21",
            "Service Charge 10% 25.00",
            "VAT 12% 26.79"
        ])
        #expect(parsed.items == [ParsedReceiptItem(name: "Adobo", price: 250.0, quantity: 1)])
        #expect(parsed.taxes == [
            ParsedAdjustment(name: "Service Charge 10%", price: 25.0),
            ParsedAdjustment(name: "VAT 12%", price: 26.79)
        ])
    }

    @Test func parsesParenthesisedDiscountsAndTrailingQuantities() {
        let parsed = ReceiptTextParser.parse(lines: [
            "Coke x3 4.50",
            "Member Savings (1.50)"
        ])
        #expect(parsed.items == [ParsedReceiptItem(name: "Coke", price: 4.5, quantity: 3)])
        #expect(parsed.discounts == [ParsedAdjustment(name: "Member Savings", price: 1.5)])
    }

    @Test(arguments: [
        ("1,234.56", 1234.56),
        ("1.234,56", 1234.56),
        ("12,50", 12.5),
        ("12.50", 12.5),
        ("25.000", 25000.0),
        ("1.000.000", 1_000_000.0),
        ("$4.99", 4.99),
        ("RM12.90", 12.9),
        ("12.5", 12.5)
    ])
    func normalizesAmounts(raw: String, expected: Double) {
        #expect(isClose(ReceiptTextParser.normalizeAmount(raw), expected))
    }
}
