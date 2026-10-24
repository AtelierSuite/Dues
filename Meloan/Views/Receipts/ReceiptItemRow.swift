import SwiftUI

struct ReceiptItemRow: View {

    var name: String
    var price: Double
    var priceFontSize: Double = 14.0

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            Text(name)
            Spacer()
            Text(format(price))
                .font(.system(size: priceFontSize))
                .monospaced()
        }
        .tint(.primary)
    }
}
