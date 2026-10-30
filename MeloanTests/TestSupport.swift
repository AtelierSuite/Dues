import Foundation
import SwiftData
@testable import Meloan

/// An in-memory SwiftData store. Holds the container so it outlives the context.
struct InMemoryStore {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        // Money math rounds to the currency's minor units, so pin them for predictable results.
        defaults.set(2, forKey: "DecimalPlaces")
        let schema = Schema([
            Receipt.self, Person.self, ReceiptItem.self, DiscountItem.self, TaxItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }
}

/// A dinner paid by "Me" for three people, with one item each for Alice and Me and one shared item.
///
/// Items 80.00 + tax 8.00 - discount 4.00 = 84.00, so every item costs 1.05x its price.
struct DinnerFixture {
    let store: InMemoryStore
    let mePerson: Person
    let alice: Person
    let bob: Person
    let receipt: Receipt
    let steak: ReceiptItem
    let pasta: ReceiptItem
    let wine: ReceiptItem

    init() throws {
        store = try InMemoryStore()
        mePerson = Person(name: "Me")
        mePerson.id = "ME"
        alice = Person(name: "Alice")
        bob = Person(name: "Bob")
        for person in [mePerson, alice, bob] {
            store.context.insert(person)
        }

        receipt = Receipt(name: "Dinner")
        store.context.insert(receipt)
        receipt.setPersonWhoPaid(to: mePerson)
        receipt.addPeopleWhoParticipated(from: [mePerson, alice, bob])

        steak = ReceiptItem(name: "Steak", price: 30.0, amount: 1)
        steak.setPurchaser(to: alice)
        pasta = ReceiptItem(name: "Pasta", price: 20.0, amount: 1)
        pasta.setPurchaser(to: mePerson)
        wine = ReceiptItem(name: "Wine", price: 30.0, amount: 1)
        receipt.addReceiptItems(from: [steak, pasta, wine])
        receipt.addTaxItems(from: [TaxItem(name: "Tax", price: 8.0)])
        receipt.addDiscountItems(from: [DiscountItem(name: "Coupon", price: 4.0)])
        try store.context.save()
    }
}

func isClose(_ value: Double?, _ expected: Double, tolerance: Double = 0.000_001) -> Bool {
    guard let value = value else { return false }
    return abs(value - expected) <= tolerance
}
