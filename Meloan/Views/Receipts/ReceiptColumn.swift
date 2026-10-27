import Komponents
import SwiftData
import SwiftUI

struct ReceiptColumn: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @State var receipt: Receipt

    var receiptCornerRadius: CGFloat {
        if #available(iOS 26.0, *) {
            return 20.0
        } else {
            return 10.0
        }
    }

    // Derived from the receipt ID so the stamp texture stays put across redraws.
    var stampNoiseOffset: CGSize {
        let seed = receipt.id.unicodeScalars.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1.value) }
        return CGSize(width: CGFloat(seed % 100) - 50.0,
                      height: CGFloat((seed / 100) % 100) - 50.0)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0.0) {
            Text(receipt.name)
                .bold()
                .padding()
            Divider()
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 8.0) {
                    Group {
                        ForEach(receipt.items()) { item in
                            ReceiptItemCompactRow(name: item.name, price: item.price,
                                                  isPaid: item.paid, person: item.person)
                        }
                        if !receipt.discountItems().isEmpty {
                            Divider()
                            ForEach(receipt.discountItems()) { item in
                                ReceiptItemCompactRow(name: item.name, price: item.price)
                            }
                        }
                        if !receipt.taxItems().isEmpty {
                            Divider()
                            ForEach(receipt.taxItems()) { item in
                                ReceiptItemCompactRow(name: item.name, price: item.price)
                            }
                        }
                        Divider()
                        ReceiptItemCompactRow(name: NSLocalizedString("Receipt.Total", comment: ""),
                                              price: receipt.sum(), hidesPhoto: true)
                    }
                    .padding([.leading, .trailing])
                }
                .padding([.top, .bottom])
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .overlay {
                if receipt.isPaid() {
                    ZStack(alignment: .center) {
                        Text("Receipt.Paid")
                            .textCase(.uppercase)
                            .font(.system(size: 50.0, weight: .black))
                            .foregroundStyle(.accent)
                            .padding([.leading, .trailing], 16.0)
                            .padding([.top, .bottom], 8.0)
                            .background {
                                RoundedRectangle(cornerRadius: 10.0)
                                    .stroke(lineWidth: 5.0)
                                    .foregroundStyle(.accent)
                            }
                            .mask {
                                Image("Noise")
                                    .resizable()
                                    .scaledToFill()
                                    .scaleEffect(2.5)
                                    .offset(stampNoiseOffset)
                            }
                            .rotationEffect(Angle(degrees: 320.0))
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(.background.opacity(0.75))
                }
            }
            Divider()
            ActionButton(text: "Receipt.ShowDetails", icon: "Receipt.ShowDetails", isPrimary: true) {
                navigationManager.push(ViewPath.receiptDetail(receipt: receipt), for: .receipts)
            }
            .padding()
        }
        .background(Color(uiColor: UIColor.secondarySystemGroupedBackground))
        .frame(width: 288.0)
        .clipShape(RoundedRectangle(cornerRadius: receiptCornerRadius))
    }
}
