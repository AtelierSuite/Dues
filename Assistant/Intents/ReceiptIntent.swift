import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct ReceiptIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget.Receipt.Config.Title"
    static var description = IntentDescription("Widget.Receipt.Config.Description")

    @Parameter(title: "Widget.Receipt.Config.Label") var receipt: ReceiptEntity?

    init(receipt: ReceiptEntity) {
        self.receipt = receipt
    }

    init() { }

}
