import Foundation
import TipKit

struct ReceiptsTip: Tip {
    var title: Text {
        Text("Receipts.Tip.Title")
    }
    var message: Text? {
        Text("Receipts.Tip.Text")
    }
    var image: Image? {
        Image(systemName: "scroll.fill")
    }
}
