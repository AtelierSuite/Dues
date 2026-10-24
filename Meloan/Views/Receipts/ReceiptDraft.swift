import Foundation
import Observation

@Observable
class ReceiptDraft {

    struct Item: Identifiable, Equatable {
        var id: String
        var name: String
        var price: Double
        var person: Person?
        var dateAdded: Date
    }

    struct Discount: Identifiable, Equatable {
        var id = UUID().uuidString
        var name: String
        var price: Double
        var dateAdded: Date
    }

    struct Tax: Identifiable, Equatable {
        var id: String
        var name: String
        var price: Double
        var dateAdded: Date
    }

    var name: String
    var receiptItems: [Item]
    var discountItems: [Discount]
    var taxItems: [Tax]
    var personWhoPaid: Person?
    var peopleWhoParticipated: [Person]?
    var isApplyingUndoRedo: Bool = false

    init(from receipt: Receipt) {
        self.name = receipt.name
        self.personWhoPaid = receipt.personWhoPaid
        self.peopleWhoParticipated = receipt.peopleWhoParticipated
        self.receiptItems = receipt.items().map { item in
            Item(id: item.id, name: item.name, price: item.price,
                 person: item.person, dateAdded: item.dateAdded)
        }
        self.discountItems = receipt.discountItems().map { item in
            Discount(name: item.name, price: item.price,
                     dateAdded: item.dateAdded)
        }
        self.taxItems = receipt.taxItems().map { item in
            Tax(id: item.id, name: item.name, price: item.price,
                dateAdded: item.dateAdded)
        }
    }

    func participants() -> [Person] {
        guard let peopleWhoParticipated = peopleWhoParticipated else { return [] }
        var result: [Person] = []
        if let mePerson = peopleWhoParticipated.first(where: { $0.id == "ME" }) {
            result.append(mePerson)
        }
        let remaining = peopleWhoParticipated
            .filter { $0.id != "ME" }
            .sorted { $0.name < $1.name }
        result.append(contentsOf: remaining)
        return result
    }
}
