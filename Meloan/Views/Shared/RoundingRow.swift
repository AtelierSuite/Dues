import SwiftUI

/// Shows the warikan rounding difference that goes to the payer, when there is one.
struct RoundingRow: View {

    var difference: Double

    var body: some View {
        if isVisibleRounding(difference) {
            HStack(alignment: .center, spacing: 4.0) {
                Text("Shared.Rounding")
                Spacer()
                Text(verbatim: "+\(format(difference))")
                    .font(.system(size: 14.0))
                    .monospaced()
            }
            .foregroundStyle(.secondary)
        }
    }
}
