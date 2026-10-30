import SwiftUI

struct ReceiptItemRow: View {

    var name: String
    var price: Double
    var priceFont: Font = .subheadline

    var body: some View {
        HStack(alignment: .center, spacing: 8.0) {
            Text(name)
            Spacer()
            Text(format(price))
                .font(priceFont)
                .monospaced()
        }
        .tint(.primary)
    }
}
