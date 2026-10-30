import Foundation
import SwiftData

struct ReceiptSnapshot {

    struct Item {
        let id: String
        let name: String
        let price: Double
        let amount: Int
        let paid: Bool
        let personID: String?
        let paidByIDs: [String]
        let dateAdded: Date
    }

    struct Tax {
        let id: String
        let name: String
        let price: Double
        let dateAdded: Date
    }

    struct Discount {
        let id: String
        let name: String
        let price: Double
        let dateAdded: Date
    }

    let id: String
    let name: String
    let dateAdded: Date
    let payerID: String?
    let participantIDs: [String]
    let items: [Item]
    let taxes: [Tax]
    let discounts: [Discount]

    init(receipt: Receipt) {
        id = receipt.id
        name = receipt.name
        dateAdded = receipt.dateAdded
        payerID = receipt.personWhoPaid?.id
        participantIDs = (receipt.peopleWhoParticipated ?? []).map { $0.id }
        items = receipt.items(sorted: false).map { item in
            Item(id: item.id, name: item.name, price: item.price, amount: item.amount,
                 paid: item.paid, personID: item.person?.id,
                 paidByIDs: (item.peopleWhoPaid ?? []).map { $0.id }, dateAdded: item.dateAdded)
        }
        taxes = receipt.taxItems(sorted: false).map {
            Tax(id: $0.id, name: $0.name, price: $0.price, dateAdded: $0.dateAdded)
        }
        discounts = receipt.discountItems(sorted: false).map {
            Discount(id: $0.id, name: $0.name, price: $0.price, dateAdded: $0.dateAdded)
        }
    }

    /// Rebuilds the receipt and inserts it, re-linking the still-existing people.
    @discardableResult
    func restore(into context: ModelContext, people: [Person]) -> Receipt {
        func person(_ identifier: String?) -> Person? {
            guard let identifier = identifier else { return nil }
            return people.first { $0.id == identifier }
        }
        let receipt = Receipt(name: name)
        receipt.id = id
        receipt.dateAdded = dateAdded
        receipt.personWhoPaid = person(payerID)
        receipt.peopleWhoParticipated = participantIDs.compactMap { person($0) }
        for snapshot in items {
            let item = ReceiptItem(name: snapshot.name, price: snapshot.price, amount: snapshot.amount)
            item.id = snapshot.id
            item.dateAdded = snapshot.dateAdded
            item.paid = snapshot.paid
            item.person = person(snapshot.personID)
            item.peopleWhoPaid = snapshot.paidByIDs.compactMap { person($0) }
            receipt.addReceiptItems(from: [item])
        }
        for snapshot in taxes {
            let tax = TaxItem(name: snapshot.name, price: snapshot.price)
            tax.id = snapshot.id
            tax.dateAdded = snapshot.dateAdded
            receipt.addTaxItems(from: [tax])
        }
        for snapshot in discounts {
            let discount = DiscountItem(name: snapshot.name, price: snapshot.price)
            discount.id = snapshot.id
            discount.dateAdded = snapshot.dateAdded
            receipt.addDiscountItems(from: [discount])
        }
        context.insert(receipt)
        try? context.save()
        return receipt
    }
}
