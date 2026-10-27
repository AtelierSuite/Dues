import Foundation
import SwiftData

@Model
final class Receipt: Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    @Relationship(deleteRule: .cascade) var receiptItems: [ReceiptItem]? = []
    @Relationship(deleteRule: .cascade) var discountItems: [DiscountItem]? = []
    @Relationship(deleteRule: .cascade) var taxItems: [TaxItem]? = []
    @Relationship(deleteRule: .nullify) var personWhoPaid: Person?
    @Relationship(deleteRule: .nullify) var peopleWhoParticipated: [Person]? = []
    var dateAdded: Date = Date.now

    init(name: String) {
        self.name = name
    }

    func items(sorted: Bool = true) -> [ReceiptItem] {
        if let receiptItems = receiptItems {
            if sorted {
                return receiptItems.sorted(by: { $0.dateAdded < $1.dateAdded })
            } else {
                return receiptItems
            }
        }
        return []
    }

    func discountItems(sorted: Bool = true) -> [DiscountItem] {
        if let discountItems = discountItems {
            if sorted {
                return discountItems.sorted(by: { $0.dateAdded < $1.dateAdded })
            } else {
                return discountItems
            }
        }
        return []
    }

    func taxItems(sorted: Bool = true) -> [TaxItem] {
        if let taxItems = taxItems {
            if sorted {
                return taxItems.sorted(by: { $0.dateAdded < $1.dateAdded })
            } else {
                return taxItems
            }
        }
        return []
    }

    func sum() -> Double {
        return sumOfItems() + sumOfTax() - sumOfDiscount()
    }

    func sumUnpaid() -> Double {
        return (receiptItems?.reduce(into: 0.0, { partialResult, item in
            if !item.paid {
                partialResult += item.price
            }
        }) ?? .zero) * overallRate()
    }

    func sumPaid() -> Double {
        return sum() - sumUnpaid()
    }

    func sumOfItems() -> Double {
        return receiptItems?.reduce(into: 0.0, { partialResult, item in
            partialResult += item.price
        }) ?? .zero
    }

    func sumOfTax() -> Double {
        return taxItems?.reduce(into: 0.0, { partialResult, item in
            partialResult += item.price
        }) ?? .zero
    }

    func sumOfDiscount() -> Double {
        return discountItems?.reduce(into: 0.0, { partialResult, item in
            partialResult += item.price
        }) ?? .zero
    }

    func taxRate() -> Double {
        if sumOfItems() > 0 {
            return sumOfTax() / sumOfItems()
        }
        return .zero
    }

    func overallRate() -> Double {
        if sumOfItems() > 0 {
            return max(0.0, sum() / sumOfItems())
        }
        return .zero
    }

    func sumOfSharedItemCost(for person: Person) -> Double {
        guard let participantCount = peopleWhoParticipated?.count, participantCount > 0 else { return .zero }
        return receiptItems?.reduce(into: 0.0, {partialResult, item in
            if item.person == nil, !item.personHasPaid(person) {
                partialResult += item.price / Double(participantCount)
            }
        }) ?? .zero
    }

    func sumOfItemCost(for person: Person) -> Double {
        return receiptItems?.reduce(into: 0.0, { partialResult, item in
            if let itemPerson = item.person, itemPerson.id == person.id, !item.paid {
                partialResult += item.price
            }
        }) ?? .zero
    }

    func sumOwed(to lender: Person, for borrower: Person) -> Double {
        if ((personWhoPaid?.id ?? "") == lender.id) && contains(participant: borrower) {
            return (sumOfItemCost(for: borrower) +
                    sumOfSharedItemCost(for: borrower)) * overallRate()
        }
        return .zero
    }

    func contains(participant person: Person) -> Bool {
        return peopleWhoParticipated?.contains(where: { $0.id == person.id }) ?? false
    }

    func participants() -> [Person] {
        if let peopleWhoParticipated = peopleWhoParticipated {
            var participants: [Person] = []
            if let mePerson = peopleWhoParticipated.first(where: { $0.id == "ME" }) {
                participants.append(mePerson)
            }
            let remainingPeopleSorted = peopleWhoParticipated
                .filter({ $0.id != "ME" })
                .sorted(by: { $0.name < $1.name })
            participants.append(contentsOf: remainingPeopleSorted)
            return participants
        }
        return []
    }

    func borrowers() -> [Person] {
        if let personWhoPaid = personWhoPaid {
            return participants().filter({ $0.id != personWhoPaid.id })
        }
        return participants()
    }

    func isPaid() -> Bool {
        let items = receiptItems ?? []
        return !items.isEmpty && !items.contains(where: { $0.paid == false })
    }

    func addReceiptItems(from receiptItems: [ReceiptItem]) {
        self.receiptItems?.append(contentsOf: receiptItems)
    }

    func addDiscountItems(from discountItems: [DiscountItem]) {
        self.discountItems?.append(contentsOf: discountItems)
    }

    func addTaxItems(from taxItems: [TaxItem]) {
        self.taxItems?.append(contentsOf: taxItems)
    }

    func setPersonWhoPaid(to personWhoPaid: Person?) {
        self.personWhoPaid = personWhoPaid
    }

    func addPeopleWhoParticipated(from peopleWhoParticipated: [Person]) {
        self.peopleWhoParticipated?.append(contentsOf: peopleWhoParticipated)
    }

    func setLenderItemsPaid() {
        guard let personWhoPaid = personWhoPaid else { return }
        let participantIDs = Set(participants().map { $0.id })
        for item in receiptItems ?? [] where item.person?.id == personWhoPaid.id {
            item.paid = true
        }
        for item in receiptItems ?? [] where item.person == nil {
            // addPersonWhoPaid is now idempotent, but guard anyway for clarity.
            if !item.personHasPaid(personWhoPaid) {
                item.addPersonWhoPaid(from: [personWhoPaid])
            }
            item.refreshSharedPaidState(participantIDs: participantIDs)
        }
    }

    func reassign(_ item: ReceiptItem, to person: Person?, markSelfPaid: Bool) {
        guard item.person?.id != person?.id else { return }
        item.person = person
        item.peopleWhoPaid?.removeAll()
        if let person = person {
            item.paid = markSelfPaid && person.id == personWhoPaid?.id
        } else {
            if markSelfPaid, let personWhoPaid = personWhoPaid {
                item.addPersonWhoPaid(from: [personWhoPaid])
            }
            item.refreshSharedPaidState(participantIDs: Set(participants().map { $0.id }))
        }
    }

    func toggleSettled(_ item: ReceiptItem) {
        if item.person != nil {
            item.paid.toggle()
            return
        }
        let participantList = participants()
        let participantIDs = Set(participantList.map { $0.id })
        let paidIDs = Set((item.peopleWhoPaid ?? []).map { $0.id })
        let allPaid = !participantIDs.isEmpty && participantIDs.isSubset(of: paidIDs)
        if allPaid {
            // Clear the borrowers, but keep the payer settled — they paid the bill.
            item.peopleWhoPaid?.removeAll()
            if let personWhoPaid = personWhoPaid {
                item.addPersonWhoPaid(from: [personWhoPaid])
            }
        } else {
            item.addPersonWhoPaid(from: participantList)
        }
        item.refreshSharedPaidState(participantIDs: participantIDs)
    }

    func toggleSettled(_ item: ReceiptItem, for person: Person) {
        if item.person != nil {
            item.paid.toggle()
            return
        }
        if item.personHasPaid(person) {
            item.removePersonWhoPaid(withID: person.id)
        } else {
            item.addPersonWhoPaid(from: [person])
        }
        item.refreshSharedPaidState(participantIDs: Set(participants().map { $0.id }))
    }
}
