import Foundation

struct TaxRate: Codable, Hashable {
    var type: TRType
    var rate: Double
    var states: [String: TaxRate]?

    typealias List = [String: TaxRate]

    enum TRType: String, Codable {
        case none = "none"
        case goodsServicesTax = "gst"
        case valueAddedTax = "vat"
    }
}
