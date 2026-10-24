import Foundation
import TipKit

struct IOUTip: Tip {
    var title: Text {
        Text("IOU.Tip.Title")
    }
    var message: Text? {
        Text("IOU.Tip.Text")
    }
    var image: Image? {
        Image(systemName: "filemenu.and.selection")
    }
}
