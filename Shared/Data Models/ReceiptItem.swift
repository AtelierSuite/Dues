import Foundation
import SwiftData

@Model
final class ReceiptItem {
    var id: String = UUID().uuidString
    var name: String = ""
    var price: Double = 0.0
    var amount: Int = 0
    var paid: Bool = false
    @Relationship(deleteRule: .nullify) var person: Person?
    @Relationship(deleteRule: .nullify) var peopleWhoPaid: [Person]? = []
    @Relationship(inverse: \Receipt.receiptItems) var receipts: [Receipt]? = []
    var dateAdded: Date = Date.now

    init(name: String, price: Double, amount: Int) {
        self.name = name
        self.price = price
        self.amount = amount
    }

    func setPurchaser(to person: Person?) {
        self.person = person
    }

    func personHasPaid(_ person: Person) -> Bool {
        return peopleWhoPaid?.contains(where: { $0.id == person.id }) ?? false
    }

    func addPersonWhoPaid(from people: [Person]) {
        for person in people where !personHasPaid(person) {
            peopleWhoPaid?.append(person)
        }
    }

    func removePersonWhoPaid(withID id: String) {
        peopleWhoPaid?.removeAll(where: { $0.id == id })
    }

    func refreshSharedPaidState(participantIDs: Set<String>) {
        let paidIDs = Set((peopleWhoPaid ?? []).map { $0.id })
        paid = !participantIDs.isEmpty && participantIDs.isSubset(of: paidIDs)
    }
}
