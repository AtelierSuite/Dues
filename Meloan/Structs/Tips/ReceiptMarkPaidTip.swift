import Foundation
import TipKit

struct ReceiptMarkPaidTip: Tip {
    var title: Text {
        Text("Receipt.MarkPaid.Tip.Title")
    }
    var message: Text? {
        Text("Receipt.MarkPaid.Tip.Text")
    }
    var image: Image? {
        Image(systemName: "checklist")
    }
}
