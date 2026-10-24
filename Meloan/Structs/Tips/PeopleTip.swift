import Foundation
import TipKit

struct PeopleTip: Tip {
    var title: Text {
        Text("People.Tip.Title")
    }
    var message: Text? {
        Text("People.Tip.Text")
    }
    var image: Image? {
        Image(systemName: "person.fill.badge.plus")
    }
}
