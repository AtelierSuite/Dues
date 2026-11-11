import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Looks up and saves the models behind the app's Siri and Shortcuts intents, in the same
/// container the app's views read from, so changes show up in the app immediately.
@MainActor
enum IntentStore {

    static var context: ModelContext {
        sharedModelContainer.mainContext
    }

    static func receipt(_ entity: ReceiptEntity) throws -> Receipt {
        let id = entity.id
        var descriptor = FetchDescriptor<Receipt>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let receipt = try context.fetch(descriptor).first else {
            throw IntentError.receiptNotFound
        }
        return receipt
    }

    static func person(_ entity: PersonEntity) throws -> Person {
        let id = entity.id
        var descriptor = FetchDescriptor<Person>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let person = try context.fetch(descriptor).first else {
            throw IntentError.personNotFound
        }
        return person
    }

    static func people(_ entities: [PersonEntity]) throws -> [Person] {
        try entities.map { try person($0) }
    }

    static func item(_ entity: ReceiptItemEntity) throws -> ReceiptItem {
        let id = entity.id
        var descriptor = FetchDescriptor<ReceiptItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let item = try context.fetch(descriptor).first else {
            throw IntentError.itemNotFound
        }
        return item
    }

    /// The "Mark My Items as Paid" setting, which the receipt editor also honors.
    static var marksSelfPaid: Bool {
        defaults.object(forKey: "MarkSelfPaid") == nil || defaults.bool(forKey: "MarkSelfPaid")
    }

    static func save() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case receiptNotFound
    case personNotFound
    case itemNotFound
    case itemNotOnReceipt
    case personNotOnReceipt
    case emptyName
    case negativePrice
    case noTipToAdd
    case nothingToChange
    case nothingOwed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .receiptNotFound: "That receipt couldn't be found."
        case .personNotFound: "That person couldn't be found."
        case .itemNotFound: "That item couldn't be found."
        case .itemNotOnReceipt: "That item isn't on a receipt."
        case .personNotOnReceipt: "That person isn't on this receipt."
        case .emptyName: "The name can't be empty."
        case .negativePrice: "The price can't be negative."
        case .noTipToAdd: "There's no tip to add. The total may already be at that amount."
        case .nothingToChange: "There's nothing to change."
        case .nothingOwed(let name): "\(name) doesn't owe you anything."
        }
    }
}
