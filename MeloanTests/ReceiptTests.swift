import Foundation
import Testing
@testable import Meloan

struct ReceiptSumTests {

    @Test func sumIsItemsPlusTaxMinusDiscount() throws {
        let dinner = try DinnerFixture()
        #expect(isClose(dinner.receipt.sumOfItems(), 80.0))
        #expect(isClose(dinner.receipt.sumOfTax(), 8.0))
        #expect(isClose(dinner.receipt.sumOfDiscount(), 4.0))
        #expect(isClose(dinner.receipt.sum(), 84.0))
    }

    @Test func emptyReceiptSumsToZero() throws {
        let store = try InMemoryStore()
        let receipt = Receipt(name: "Empty")
        store.context.insert(receipt)
        #expect(receipt.sum() == 0.0)
        #expect(receipt.overallRate() == 0.0)
    }

    @Test func overallRateSpreadsTaxAndDiscountOverItems() throws {
        let dinner = try DinnerFixture()
        #expect(isClose(dinner.receipt.overallRate(), 1.05))
    }

    @Test func overallRateIsZeroWithoutItems() throws {
        let store = try InMemoryStore()
        let receipt = Receipt(name: "Only Tax")
        store.context.insert(receipt)
        receipt.addTaxItems(from: [TaxItem(name: "Tax", price: 5.0)])
        #expect(receipt.overallRate() == 0.0)
    }

    @Test func overallRateNeverGoesNegative() throws {
        let store = try InMemoryStore()
        let receipt = Receipt(name: "Free Lunch")
        store.context.insert(receipt)
        receipt.addReceiptItems(from: [ReceiptItem(name: "Lunch", price: 10.0, amount: 1)])
        receipt.addDiscountItems(from: [DiscountItem(name: "Voucher", price: 15.0)])
        #expect(isClose(receipt.sum(), -5.0))
        #expect(receipt.overallRate() == 0.0)
    }
}

struct ReceiptSettlementTests {

    // MARK: - sumOfSharedItemCost

    @Test func sharedItemCostIsSplitEvenlyBetweenParticipants() throws {
        let dinner = try DinnerFixture()
        #expect(isClose(dinner.receipt.sumOfSharedItemCost(for: dinner.alice), 10.0))
        #expect(isClose(dinner.receipt.sumOfSharedItemCost(for: dinner.bob), 10.0))
    }

    @Test func sharedItemCostExcludesItemsThePersonHasPaid() throws {
        let dinner = try DinnerFixture()
        dinner.wine.addPersonWhoPaid(from: [dinner.alice])
        #expect(dinner.receipt.sumOfSharedItemCost(for: dinner.alice) == 0.0)
        #expect(isClose(dinner.receipt.sumOfSharedItemCost(for: dinner.bob), 10.0))
    }

    @Test func sharedItemCostIsZeroWithoutParticipants() throws {
        let store = try InMemoryStore()
        let person = Person(name: "Solo")
        let receipt = Receipt(name: "Nobody")
        store.context.insert(person)
        store.context.insert(receipt)
        receipt.addReceiptItems(from: [ReceiptItem(name: "Shared", price: 12.0, amount: 1)])
        #expect(receipt.sumOfSharedItemCost(for: person) == 0.0)
    }

    // MARK: - sumOwed(to:for:)

    @Test func borrowerOwesTheirItemsAndShareScaledByOverallRate() throws {
        let dinner = try DinnerFixture()
        // Alice: (30 steak + 10 wine share) x 1.05
        #expect(isClose(dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.alice), 42.0))
        // Bob: 10 wine share x 1.05
        #expect(isClose(dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.bob), 10.5))
    }

    @Test func nothingIsOwedToSomeoneWhoDidNotPay() throws {
        let dinner = try DinnerFixture()
        #expect(dinner.receipt.sumOwed(to: dinner.alice, for: dinner.bob) == 0.0)
    }

    @Test func nonParticipantOwesNothing() throws {
        let dinner = try DinnerFixture()
        let carol = Person(name: "Carol")
        dinner.store.context.insert(carol)
        #expect(dinner.receipt.sumOwed(to: dinner.mePerson, for: carol) == 0.0)
    }

    @Test func paidItemsAreNoLongerOwed() throws {
        let dinner = try DinnerFixture()
        dinner.steak.paid = true
        #expect(isClose(dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.alice), 10.5))
        dinner.wine.addPersonWhoPaid(from: [dinner.alice])
        #expect(dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.alice) == 0.0)
    }

    @Test func personSumOwedAddsUpReceiptsPaidByLender() throws {
        let dinner = try DinnerFixture()
        #expect(isClose(dinner.alice.sumOwed(to: dinner.mePerson), 42.0))
        #expect(dinner.alice.sumOwed(to: dinner.bob) == 0.0)
        #expect(dinner.alice.sumOwed(to: nil) == 0.0)
    }

    // MARK: - isPaid

    @Test func receiptWithoutItemsIsNotPaid() throws {
        let store = try InMemoryStore()
        let receipt = Receipt(name: "Empty")
        store.context.insert(receipt)
        #expect(!receipt.isPaid())
    }

    @Test func receiptIsPaidOnlyWhenEveryItemIsPaid() throws {
        let dinner = try DinnerFixture()
        #expect(!dinner.receipt.isPaid())
        dinner.steak.paid = true
        dinner.pasta.paid = true
        #expect(!dinner.receipt.isPaid())
        dinner.wine.paid = true
        #expect(dinner.receipt.isPaid())
    }

    // MARK: - setLenderItemsPaid

    @Test func setLenderItemsPaidSettlesThePayersShare() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.setLenderItemsPaid()
        #expect(dinner.pasta.paid)
        #expect(!dinner.steak.paid)
        #expect(dinner.wine.personHasPaid(dinner.mePerson))
        #expect(!dinner.wine.personHasPaid(dinner.alice))
        #expect(!dinner.wine.paid)
        // Running it again must not add the payer twice.
        dinner.receipt.setLenderItemsPaid()
        #expect(dinner.wine.peopleWhoPaid?.count == 1)
    }

    @Test func setLenderItemsPaidMarksSharedItemPaidWhenPayerIsOnlyParticipant() throws {
        let store = try InMemoryStore()
        let mePerson = Person(name: "Me")
        let receipt = Receipt(name: "Solo")
        let snack = ReceiptItem(name: "Snack", price: 5.0, amount: 1)
        store.context.insert(mePerson)
        store.context.insert(receipt)
        receipt.setPersonWhoPaid(to: mePerson)
        receipt.addPeopleWhoParticipated(from: [mePerson])
        receipt.addReceiptItems(from: [snack])
        receipt.setLenderItemsPaid()
        #expect(snack.paid)
        #expect(receipt.isPaid())
    }

    @Test func setLenderItemsPaidWithoutPayerDoesNothing() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.setPersonWhoPaid(to: nil)
        dinner.receipt.setLenderItemsPaid()
        #expect(!dinner.pasta.paid)
        #expect(dinner.wine.peopleWhoPaid?.isEmpty ?? true)
    }

    // MARK: - toggleSettled(_:)

    @Test func toggleSettledFlipsAnOwnedItem() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.toggleSettled(dinner.steak)
        #expect(dinner.steak.paid)
        dinner.receipt.toggleSettled(dinner.steak)
        #expect(!dinner.steak.paid)
    }

    @Test func toggleSettledSettlesASharedItemForEveryone() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.toggleSettled(dinner.wine)
        #expect(dinner.wine.paid)
        for person in [dinner.mePerson, dinner.alice, dinner.bob] {
            #expect(dinner.wine.personHasPaid(person))
        }
        #expect(dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.bob) == 0.0)
    }

    @Test func toggleSettledUnsettlesASharedItemButKeepsThePayer() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.toggleSettled(dinner.wine)
        dinner.receipt.toggleSettled(dinner.wine)
        #expect(!dinner.wine.paid)
        #expect(dinner.wine.personHasPaid(dinner.mePerson))
        #expect(!dinner.wine.personHasPaid(dinner.alice))
        #expect(!dinner.wine.personHasPaid(dinner.bob))
    }

    @Test func toggleSettledCompletesAPartiallyPaidSharedItem() throws {
        let dinner = try DinnerFixture()
        dinner.wine.addPersonWhoPaid(from: [dinner.alice])
        dinner.receipt.toggleSettled(dinner.wine)
        #expect(dinner.wine.paid)
        #expect(dinner.wine.peopleWhoPaid?.count == 3)
    }

    // MARK: - toggleSettled(_:for:)

    @Test func toggleSettledForPersonFlipsAnOwnedItem() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.toggleSettled(dinner.steak, for: dinner.alice)
        #expect(dinner.steak.paid)
        dinner.receipt.toggleSettled(dinner.steak, for: dinner.alice)
        #expect(!dinner.steak.paid)
    }

    @Test func toggleSettledForPersonTracksEachShareSeparately() throws {
        let dinner = try DinnerFixture()
        dinner.receipt.toggleSettled(dinner.wine, for: dinner.alice)
        #expect(dinner.wine.personHasPaid(dinner.alice))
        #expect(!dinner.wine.paid)
        #expect(isClose(dinner.receipt.sumOwed(to: dinner.mePerson, for: dinner.alice), 31.5))

        dinner.receipt.toggleSettled(dinner.wine, for: dinner.bob)
        dinner.receipt.toggleSettled(dinner.wine, for: dinner.mePerson)
        #expect(dinner.wine.paid)

        dinner.receipt.toggleSettled(dinner.wine, for: dinner.alice)
        #expect(!dinner.wine.personHasPaid(dinner.alice))
        #expect(!dinner.wine.paid)
    }
}
