import WidgetKit
import SwiftData
import SwiftUI

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        ReceiptProgressWidget()
        ReceiptItemsWidget()
        ReceiptIOUWidget()
    }
}
