import SwiftUI

/// Shows how much of the rounded shares above is rounding that goes to the payer, when there is any.
struct RoundingRow: View {

    var difference: Double

    var body: some View {
        if isVisibleRounding(difference) {
            HStack(alignment: .center, spacing: 4.0) {
                Text("Shared.Rounding")
                Spacer()
                Text(format(difference))
                    .font(.system(size: 14.0))
                    .monospaced()
            }
            .foregroundStyle(.secondary)
        }
    }
}
