import Foundation

let currencies: [String] = Bundle.main.decode([String].self, from: "Currencies.json")!
let taxRates: TaxRate.List = Bundle.main.decode(TaxRate.List.self, from: "TaxRates.json")!
