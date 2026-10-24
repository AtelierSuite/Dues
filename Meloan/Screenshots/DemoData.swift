import Foundation
import SwiftData
import UIKit

/// The people and receipts shown in the App Store screenshots, in English or Japanese to match
/// the language the app runs in.
enum DemoData {

    static let dinnerWithAliceID = "demo-dinner-with-alice"
    static let teamDinnerID = "demo-team-dinner"

    static let inMemoryContainer: ModelContainer = {
        let schema = Schema([
            Receipt.self, Person.self, ReceiptItem.self, DiscountItem.self, TaxItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the demo ModelContainer: \(error)")
        }
    }()

    static var peopleSearchTerm: String { localized("Alice", "赤木") }
    static var itemsSearchTerm: String { localized("Steak", "ステーキ") }

    private static var isJapanese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static func localized(_ english: String, _ japanese: String) -> String {
        isJapanese ? japanese : english
    }

    // MARK: - Seeding

    @MainActor
    static func replaceAll(in modelContext: ModelContext) {
        try? modelContext.delete(model: Receipt.self)
        try? modelContext.delete(model: ReceiptItem.self)
        try? modelContext.delete(model: DiscountItem.self)
        try? modelContext.delete(model: TaxItem.self)
        try? modelContext.delete(model: Person.self)

        let mePerson = Person(name: NSLocalizedString("People.Me", comment: ""))
        mePerson.id = "ME"
        mePerson.photo = UIImage(named: "Profile.Me.Circle")?.pngData()
        // The avatars carry the initial of the name in each language.
        let alice = person(localized("Alice", "赤木"), photo: "Akagi")
        let kris = person(localized("Kris", "黒子"), photo: "Kuroko")
        let mark = person(localized("Mark", "村本"), photo: "Muramoto")
        for person in [mePerson, alice, kris, mark] {
            modelContext.insert(person)
        }

        // Newest first on the Receipts tab.
        let now = Date.now
        let receipts = [
            dinnerWithAlice(payer: mePerson, alice: alice),
            teamDinner(payer: mePerson, alice: alice, kris: kris, mark: mark),
            groupOrder(payer: mePerson, kris: kris, mark: mark),
            drinks(payer: alice, mePerson: mePerson, kris: kris, mark: mark)
        ]
        for (index, receipt) in receipts.enumerated() {
            receipt.dateAdded = now.addingTimeInterval(-Double(index) * 86400)
            modelContext.insert(receipt)
        }
        try? modelContext.save()
    }

    private static func person(_ name: String, photo: String) -> Person {
        Person(name: name, photo: UIImage(named: photo)?.pngData())
    }

    /// A purchased item, assigned to `person` or shared when there is none.
    private struct Item {
        let name: String
        let price: Double
        let person: Person?

        init(_ name: String, _ price: Double, _ person: Person?) {
            self.name = name
            self.price = price
            self.person = person
        }
    }

    // Items are spaced a second apart so that they keep their order.
    // swiftlint:disable:next function_parameter_count
    private static func makeReceipt(_ id: String, name: String, payer: Person, participants: [Person],
                                    items: [Item], taxes: [(name: String, price: Double)]) -> Receipt {
        let receipt = Receipt(name: name)
        receipt.id = id
        let start = Date.now
        receipt.addReceiptItems(from: items.enumerated().map { index, item in
            let receiptItem = ReceiptItem(name: item.name, price: item.price, amount: 1)
            receiptItem.person = item.person
            receiptItem.dateAdded = start.addingTimeInterval(Double(index))
            return receiptItem
        })
        receipt.addTaxItems(from: taxes.enumerated().map { index, tax in
            let taxItem = TaxItem(name: tax.name, price: tax.price)
            taxItem.dateAdded = start.addingTimeInterval(Double(index))
            return taxItem
        })
        receipt.setPersonWhoPaid(to: payer)
        receipt.addPeopleWhoParticipated(from: participants)
        receipt.setLenderItemsPaid()
        return receipt
    }

    /// Marks a shared item paid by some of the participants, or an assigned item as paid.
    private static func settle(_ itemName: String, in receipt: Receipt, by people: [Person] = []) {
        guard let item = receipt.items().first(where: { $0.name == itemName }) else { return }
        if item.person != nil {
            item.paid = true
        } else {
            for person in people {
                receipt.toggleSettled(item, for: person)
            }
        }
    }

    // MARK: - Receipts

    private static func dinnerWithAlice(payer: Person, alice: Person) -> Receipt {
        makeReceipt(dinnerWithAliceID, name: localized("Dinner With Alice", "赤木さんとディナー"),
                    payer: payer, participants: [payer, alice],
                    items: [
                        Item(localized("Appetizers", "前菜"), 10.0, nil),
                        Item(localized("Spaghetti Bolognese", "スパゲッティ・ボロネーゼ"), 14.0, payer),
                        Item(localized("Steak And Mash", "ステーキ＆マッシュポテト"), 21.0, alice),
                        Item(localized("Beer Tower", "ビアタワー"), 49.0, nil)
                    ],
                    taxes: [
                        (localized("Goods and Services Tax", "消費税"), 7.52),
                        (localized("Service Charge", "サービス料"), 9.40)
                    ])
    }

    private static func teamDinner(payer: Person, alice: Person, kris: Person, mark: Person) -> Receipt {
        let steakPlatter = localized("Steak Platter", "ステーキプラッター")
        let carbonara = localized("Spaghetti Carbonara (Extra Sauce, Extra Cheese)",
                                  "カルボナーラ（ソース・チーズ増量）")
        let sirloin = localized("Sirloin Steak (Black Pepper Sauce)", "サーロインステーキ（黒胡椒ソース）")
        let iceWater = localized("Ice Water", "お冷や")
        let receipt = makeReceipt(teamDinnerID, name: localized("Team Dinner at Johnny's Diner",
                                                                "Johnny's Dinerでチームディナー"),
                                  payer: payer, participants: [payer, alice, kris, mark],
                                  items: [
                                    Item(steakPlatter, 42.0, nil),
                                    Item(carbonara, 12.0, alice),
                                    Item(localized("Fish & Chips", "フィッシュ＆チップス"), 11.0, mark),
                                    Item(sirloin, 16.0, kris),
                                    Item(localized("Grilled Chicken Salad", "グリルチキンサラダ"), 13.0, payer),
                                    Item(iceWater, 1.0, nil)
                                  ],
                                  taxes: [
                                    (localized("Service Charge", "サービス料"), 9.50),
                                    (localized("Goods and Services Tax", "消費税"), 9.41)
                                  ])
        settle(steakPlatter, in: receipt, by: [mark])
        settle(carbonara, in: receipt)
        settle(sirloin, in: receipt)
        settle(iceWater, in: receipt, by: [alice, kris, mark])
        return receipt
    }

    private static func groupOrder(payer: Person, kris: Person, mark: Person) -> Receipt {
        let pizza = localized("Margherita Pizza", "マルゲリータピザ")
        let fries = localized("Truffle Fries", "トリュフフライ")
        let receipt = makeReceipt("demo-group-order", name: localized("Lunch Group Order", "ランチのまとめ注文"),
                                  payer: payer, participants: [payer, kris, mark],
                                  items: [
                                    Item(localized("Tomato Basil Pasta", "トマトバジルパスタ"), 12.80, kris),
                                    Item(pizza, 18.50, nil),
                                    Item(fries, 8.90, mark),
                                    Item(localized("Iced Lemon Tea", "アイスレモンティー"), 3.20, payer),
                                    Item(localized("Delivery Fee", "配達料"), 4.99, nil)
                                  ],
                                  taxes: [
                                    (localized("Goods and Services Tax", "消費税"), 4.36)
                                  ])
        settle(pizza, in: receipt, by: [mark])
        settle(fries, in: receipt)
        return receipt
    }

    /// Paid by someone else and settled in full, so it stays out of the IOUs owed to me.
    private static func drinks(payer: Person, mePerson: Person, kris: Person, mark: Person) -> Receipt {
        let receipt = makeReceipt("demo-drinks", name: localized("Friday Drinks", "金曜日の飲み会"),
                                  payer: payer, participants: [mePerson, payer, kris, mark],
                                  items: [
                                    Item(localized("Beer Pitcher", "ピッチャービール"), 38.0, nil),
                                    Item(localized("Highball", "ハイボール"), 9.0, mePerson),
                                    Item(localized("Lemon Sour", "レモンサワー"), 8.0, kris),
                                    Item(localized("Cola", "コーラ"), 4.0, mark),
                                    Item(localized("Edamame", "枝豆"), 6.0, nil)
                                  ],
                                  taxes: [
                                    (localized("Service Charge", "サービス料"), 6.50)
                                  ])
        for item in receipt.items() where !item.paid {
            if item.person != nil {
                item.paid = true
            } else {
                receipt.toggleSettled(item)
            }
        }
        return receipt
    }
}
