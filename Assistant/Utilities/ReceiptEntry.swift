import Foundation
import WidgetKit

struct ReceiptEntry: TimelineEntry {
    var date: Date = Date.now
    var receipt: Receipt?
}
