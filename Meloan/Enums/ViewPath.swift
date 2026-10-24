import Foundation

enum ViewPath: Hashable {
    case receiptDetail(receipt: Receipt)
    case receiptItemDetail(receiptItem: ReceiptItem)
    case personCreator
    case personDetail(person: Person)
    case personEditor(person: Person)
    case moreData
    case moreTroubleshooting
    case moreLicenses
}
