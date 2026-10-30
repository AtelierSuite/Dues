import Foundation
import SwiftData
import Testing
@testable import Meloan

struct ReceiptSnapshotTests {

    /// The persisted state of a receipt item, for comparing before and after a restore.
    private struct ItemState: Equatable {
        let name: String
        let price: Double
        let amount: Int
        let paid: Bool
        let personID: String?
        let paidByIDs: Set<String>
        let dateAdded: Date

        init(_ item: ReceiptItem) {
            name = item.name
            price = item.price
            amount = item.amount
            paid = item.paid
            personID = item.person?.id
            paidByIDs = Set((item.peopleWhoPaid ?? []).map { $0.id })
            dateAdded = item.dateAdded
        }
    }

    private func itemStates(of receipt: Receipt) -> [String: ItemState] {
        Dictionary(uniqueKeysWithValues: receipt.items(sorted: false).map { ($0.id, ItemState($0)) })
    }

    private func taxStates(of receipt: Receipt) -> [String: String] {
        Dictionary(uniqueKeysWithValues: receipt.taxItems(sorted: false).map { ($0.id, "\($0.name) \($0.price)") })
    }

    /// Deletes the receipt (cascading to its items) and restores it from a snapshot taken first.
    private func deleteAndRestore(_ dinner: DinnerFixture, people: [Person]) throws -> Receipt {
        let snapshot = ReceiptSnapshot(receipt: dinner.receipt)
        dinner.store.context.delete(dinner.receipt)
        try dinner.store.context.save()
        #expect(try dinner.store.context.fetchCount(FetchDescriptor<Receipt>()) == 0)
        #expect(try dinner.store.context.fetchCount(FetchDescriptor<ReceiptItem>()) == 0)
        return snapshot.restore(into: dinner.store.context, people: people)
    }

    @Test func restoreRebuildsTheReceipt() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.setLenderItemsPaid()
        dinner.wine.addPersonWhoPaid(from: [dinner.alice])
        dinner.steak.paid = true
        let receiptID = dinner.receipt.id
        let dateAdded = dinner.receipt.dateAdded
        let originalItems = itemStates(of: dinner.receipt)
        let originalTaxes = taxStates(of: dinner.receipt)
        let originalSum = dinner.receipt.sum()
        let originalOwed = dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.bob)

        let restored = try deleteAndRestore(dinner, people: [dinner.mePerson, dinner.alice, dinner.bob])

        let fetched = try dinner.store.context.fetch(FetchDescriptor<Receipt>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.id == receiptID)
        #expect(restored.id == receiptID)
        #expect(restored.name == "Dinner")
        #expect(restored.dateAdded == dateAdded)
        #expect(restored.personWhoPaid?.id == dinner.mePerson.id)
        #expect(Set(restored.participants().map { $0.id }) ==
                Set([dinner.mePerson.id, dinner.alice.id, dinner.bob.id]))

        #expect(originalItems.count == 3)
        #expect(itemStates(of: restored) == originalItems)
        #expect(taxStates(of: restored) == originalTaxes)
        #expect(restored.discountItems(sorted: false).map { $0.name } == ["Coupon"])

        #expect(isClose(restored.sum(), originalSum))
        #expect(isClose(restored.sumOwed(to: dinner.mePerson, for: dinner.bob), originalOwed))
    }

    @Test func restoreDropsPeopleWhoNoLongerExist() throws {
        let dinner = try DinnerFixture()
        dinner.wine.addPersonWhoPaid(from: [dinner.alice, dinner.bob])

        // Alice was deleted while the undo toast was showing.
        let restored = try deleteAndRestore(dinner, people: [dinner.mePerson, dinner.bob])

        #expect(restored.personWhoPaid?.id == dinner.mePerson.id)
        #expect(Set(restored.participants().map { $0.id }) == Set([dinner.mePerson.id, dinner.bob.id]))
        let steak = try #require(restored.items(sorted: false).first { $0.name == "Steak" })
        #expect(steak.person == nil)
        let wine = try #require(restored.items(sorted: false).first { $0.name == "Wine" })
        #expect(Set((wine.peopleWhoPaid ?? []).map { $0.id }) == Set([dinner.bob.id]))
    }
}
