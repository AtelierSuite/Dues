import SwiftUI

struct ReceiptItemCompactRow: View {

    // Not read directly, but keeps the row re-rendering when the currency changes.
    @AppStorage(wrappedValue: "", "CurrencySymbol", store: defaults) var currencySymbol: String
    @AppStorage(wrappedValue: false, "UseCurrencyGlyph", store: defaults) var useCurrencyGlyph: Bool
    var name: String
    var price: Double
    var isPaid: Bool = false
    var person: Person?
    var hidesPhoto: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 8.0) {
            Group {
                if let person = person {
                    PersonAvatar(person: person, size: 16.0)
                } else {
                    Image("Profile.Shared")
                        .resizable()
                        .frame(width: 16.0, height: 16.0)
                        .clipShape(Circle())
                }
            }
            .opacity(hidesPhoto ? 0 : 1)
            Group {
                Text(name)
                Spacer()
                Text(format(price))
            }
            .strikethrough(isPaid)
            // TODO: Allow selection of currency per receipt
        }
        .font(.system(size: 14.0))
        .monospaced()
    }
}
