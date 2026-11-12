import SwiftUI

/// The receipt laid out as a single image, for sharing from the receipt and the Export Receipt intent.
struct ReceiptExportView: View {

    var receipt: Receipt

    /// Long receipts make an image too tall to be useful; those are shared as a PDF instead.
    static func fitsInImage(_ receipt: Receipt) -> Bool {
        let lineCount = (receipt.receiptItems?.count ?? 0) + (receipt.discountItems?.count ?? 0) +
            (receipt.taxItems?.count ?? 0)
        return lineCount <= 45
    }

    @MainActor
    static func renderPNG(of receipt: Receipt) -> Data? {
        let renderer = ImageRenderer(content: ReceiptExportView(receipt: receipt))
        renderer.scale = 3.0
        return renderer.uiImage?.pngData()
    }

    var body: some View {
        let items = receipt.items()
        let discountItems = receipt.discountItems()
        let taxItems = receipt.taxItems()
        let totals = receipt.totals()
        VStack(alignment: .leading, spacing: 16.0) {
            HStack(alignment: .center, spacing: 16.0) {
                Text(receipt.name)
                    .font(.system(size: 36.0))
                    .bold()
                Spacer()
                Image("PDF.Watermark")
                    .resizable()
                    .frame(width: 40.0, height: 40.0)
            }
            if !items.isEmpty {
                Divider()
                Text(NSLocalizedString("Receipt.PurchasedItems", comment: ""))
                    .font(.system(size: 28.0))
                    .bold()
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8.0) {
                        ReceiptItemRow(name: item.name, price: item.price, priceFont: .system(size: 16.0))
                            .strikethrough(item.paid)
                        HStack(alignment: .center, spacing: 8.0) {
                            if let person = item.person {
                                PersonAvatar(person: person, size: 16.0, scalesWithText: false)
                                Text(person.name)
                                    .foregroundStyle(.gray)
                            } else {
                                Image("Profile.Shared.Circle")
                                    .resizable()
                                    .frame(width: 16.0, height: 16.0)
                                Text(NSLocalizedString("Shared.Shared", comment: ""))
                                    .foregroundStyle(.gray)
                            }
                        }
                    }
                }
            }
            if !discountItems.isEmpty {
                Divider()
                Text(NSLocalizedString("Receipt.Discounts", comment: ""))
                    .font(.system(size: 28.0))
                    .bold()
                ForEach(discountItems) { item in
                    ReceiptItemRow(name: item.name, price: item.price, priceFont: .system(size: 16.0))
                }
            }
            if !taxItems.isEmpty {
                Divider()
                Text(NSLocalizedString("Receipt.Taxes", comment: ""))
                    .font(.system(size: 28.0))
                    .bold()
                ForEach(taxItems) { item in
                    ReceiptItemRow(name: item.name, price: item.price, priceFont: .system(size: 16.0))
                }
            }
            Divider()
            HStack(alignment: .center, spacing: 4.0) {
                Text(NSLocalizedString("Receipt.Total.BeforeTax", comment: ""))
                Spacer()
                Text(format(totals.items))
                    .monospaced()
            }
            HStack(alignment: .center, spacing: 4.0) {
                Text(NSLocalizedString("Receipt.Total.AfterTax", comment: ""))
                Spacer()
                Text(format(totals.total))
                    .monospaced()
            }
            .bold()
        }
        .font(.system(size: 16.0))
        .padding()
        .foregroundStyle(.primary)
        .background(.background)
    }
}
