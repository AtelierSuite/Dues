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

    /// Every receipt-level total, computed in one pass. Prefer this over calling the
    /// individual helpers repeatedly while rendering.
    func totals() -> ReceiptTotals {
        ReceiptTotals(items: sumOfItems(), tax: sumOfTax(), discount: sumOfDiscount())
    }

    func sum() -> Double {
        return Money.amount(totalMinorUnits())
    }

    func sumUnpaid() -> Double {
        let places = currencyDecimalPlaces()
        return Money.amount(itemCosts(places: places)
            .filter { !$0.item.paid }
            .reduce(0) { $0 + $1.cost }, places: places)
    }

    func sumPaid() -> Double {
        return sum() - sumUnpaid()
    }

    func sumOfItems() -> Double {
        return Money.amount(minorUnits(of: (receiptItems ?? []).map { $0.price }))
    }

    func sumOfTax() -> Double {
        return Money.amount(minorUnits(of: (taxItems ?? []).map { $0.price }))
    }

    func sumOfDiscount() -> Double {
        return Money.amount(minorUnits(of: (discountItems ?? []).map { $0.price }))
    }

    func taxRate() -> Double {
        return totals().taxRate
    }

    func sumOwed(to lender: Person, for borrower: Person) -> Double {
        let places = currencyDecimalPlaces()
        return Money.amount(minorUnitsOwed(to: lender, for: borrower, places: places), places: places)
    }

    func minorUnitsOwed(to lender: Person, for borrower: Person,
                        places: Int = currencyDecimalPlaces()) -> Int64 {
        guard (personWhoPaid?.id ?? "") == lender.id && contains(participant: borrower) else { return .zero }
        let splitters = splitOrder()
        let borrowerIndex = splitters.firstIndex(where: { $0.id == borrower.id })
        return itemCosts(places: places).reduce(into: Int64.zero) { partialResult, entry in
            if let itemPerson = entry.item.person {
                if itemPerson.id == borrower.id, !entry.item.paid {
                    partialResult += entry.cost
                }
            } else if let borrowerIndex, !entry.item.personHasPaid(borrower) {
                partialResult += Money.split(entry.cost, into: splitters.count)[borrowerIndex]
            }
        }
    }

    private func minorUnits(of prices: [Double], places: Int = currencyDecimalPlaces()) -> Int64 {
        return prices.reduce(0) { $0 + Money.minorUnits($1, places: places) }
    }

    private func totalMinorUnits(places: Int = currencyDecimalPlaces()) -> Int64 {
        return minorUnits(of: (receiptItems ?? []).map { $0.price }, places: places) +
            minorUnits(of: (taxItems ?? []).map { $0.price }, places: places) -
            minorUnits(of: (discountItems ?? []).map { $0.price }, places: places)
    }

    /// Each item's share of the receipt total (with tax and discounts applied), in minor units.
    /// The shares add up to exactly the total.
    private func itemCosts(places: Int) -> [(item: ReceiptItem, cost: Int64)] {
        let items = (receiptItems ?? []).sorted { $0.dateAdded != $1.dateAdded ?
            $0.dateAdded < $1.dateAdded : $0.id < $1.id }
        let prices = items.map { Money.minorUnits($0.price, places: places) }
        let itemsTotal = prices.reduce(0, +)
        let total = itemsTotal > 0 ? max(0, totalMinorUnits(places: places)) : 0
        return Array(zip(items, Money.allocate(total, by: prices)))
    }

    /// The order shared items are split in. The person who paid comes first, so they absorb
    /// any leftover minor units instead of the borrowers.
    private func splitOrder() -> [Person] {
        let participants = participants()
        guard let payerIndex = participants.firstIndex(where: { $0.id == personWhoPaid?.id }) else {
            return participants
        }
        var ordered = participants
        ordered.insert(ordered.remove(at: payerIndex), at: 0)
        return ordered
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
                .sorted(by: { $0.name != $1.name ? $0.name < $1.name : $0.id < $1.id })
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

struct ReceiptTotals {
    let items: Double
    let tax: Double
    let discount: Double

    var total: Double {
        items + tax - discount
    }

    var taxRate: Double {
        items > 0 ? tax / items : .zero
    }
}
