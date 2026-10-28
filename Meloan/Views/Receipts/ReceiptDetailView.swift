import ConfettiSwiftUI
import SwiftUI

// swiftlint:disable type_body_length
struct ReceiptDetailView: View {

    @Environment(\.modelContext) var modelContext
    @AppStorage(wrappedValue: true, "MarkSelfPaid", store: defaults) var markSelfPaid: Bool
    @State var receipt: Receipt
    @State var confettiCounter: Int = 0
    @State var isSharing: Bool = false
    @State private var shareImage: Image = Image(systemName: "doc.richtext")

    var body: some View {
        List {
            receiptDetails()
        }
        .task(id: shareSignature) {
            shareImage = createImageToShare()
        }
        .task {
            if ScreenshotScreen.current == .pdf {
                // Presented once the push has finished animating in.
                try? await Task.sleep(for: .seconds(1))
                isSharing = true
            }
        }
        .confettiCannon(counter: $confettiCounter, num: 60, rainHeight: 1000.0, radius: 500.0)
        .sheet(isPresented: $isSharing, content: {
            PDFExporterView(receipt: receipt)
                .presentationDragIndicator(.visible)
        })
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isSharing = true
                    } label: {
                        Label("Receipt.ExportPDF", systemImage: "doc.richtext")
                    }
                    ShareLink(item: shareImage,
                              preview: SharePreview(receipt.name, image: shareImage)) {
                        Label("Receipt.ExportImage", systemImage: "photo")
                    }
                    .disabled(receipt.items().count + receipt.discountItems().count + receipt.taxItems().count > 45)
                    ShareLink(item: createTextToShare()) {
                        Label("Receipt.ExportText", systemImage: "text.alignleft")
                    }
                } label: {
                    Label("Shared.Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(receipt.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // swiftlint:disable function_body_length
    @ViewBuilder
    func receiptDetails() -> some View {
        if let personWhoPaid = receipt.personWhoPaid {
            Section {
                NavigationLink(value: ViewPath.personDetail(person: personWhoPaid)) {
                    HStack(alignment: .center, spacing: 16.0) {
                        Label("Receipt.Payer", systemImage: "creditcard")
                        Spacer()
                        PersonRow(person: personWhoPaid)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        Section {
            ForEach(receipt.borrowers()) { person in
                NavigationLink(value: ViewPath.personDetail(person: person)) {
                    PersonRow(person: person)
                }
            }
        } header: {
            Text("Receipt.Participants")
        }
        if !receipt.items().isEmpty {
            Section {
                ForEach(receipt.items()) { item in
                    HStack(alignment: .center, spacing: 16.0) {
                        Menu {
                            Button {
                                reassign(item, to: nil)
                            } label: {
                                Image("Profile.Shared.Circle")
                                Text("Shared.Shared")
                            }
                            ForEach(receipt.participants()) { person in
                                Button {
                                    reassign(item, to: person)
                                } label: {
                                    PersonRow(person: person)
                                }
                            }
                        } label: {
                            PersonAvatar(person: item.person, size: 32.0)
                        }
                        settlementControl(for: item)
                    }
                }
            } header: {
                Text("Receipt.PurchasedItems")
                    .popoverTip(ReceiptMarkPaidTip())
            } footer: {
                HStack(alignment: .center, spacing: 4.0) {
                    Text("Receipt.Total")
                        .font(.body)
                    Spacer()
                    Text(format(receipt.sumOfItems()))
                        .font(.subheadline)
                        .monospaced()
                }
                .bold()
                .foregroundStyle(.primary)
            }
        }
        if !receipt.discountItems().isEmpty {
            Section {
                ForEach(receipt.discountItems()) { item in
                    ReceiptItemRow(name: item.name, price: item.price)
                }
            } header: {
                Text("Receipt.Discounts")
            }
        }
        if !receipt.taxItems().isEmpty {
            Section {
                ForEach(receipt.taxItems()) { item in
                    ReceiptItemRow(name: item.name, price: item.price)
                }
            } header: {
                Text("Receipt.Taxes")
            } footer: {
                HStack(alignment: .center, spacing: 4.0) {
                    Text("Receipt.Tax.Detail")
                        .font(.body)
                    Spacer()
                    Text(receipt.taxRate(), format: .percent.precision(.fractionLength(0...2)))
                        .font(.subheadline)
                        .monospaced()
                }
                .bold()
                .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    func settlementControl(for item: ReceiptItem) -> some View {
        if item.person != nil {
            Button {
                receipt.toggleSettled(item)
                afterSettlementChange()
            } label: {
                settlementRowLabel(for: item)
            }
            .accessibilityHint(Text("Receipt.Item.Settle.Hint"))
        } else {
            Menu {
                Section {
                    ForEach(receipt.participants()) { person in
                        Button {
                            receipt.toggleSettled(item, for: person)
                            afterSettlementChange()
                        } label: {
                            Label {
                                Text(verbatim: person.name)
                            } icon: {
                                Image(systemName: item.personHasPaid(person) ?
                                      "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                } header: {
                    Text("Receipt.Item.Settle.WhoPaid")
                }
                Divider()
                Button {
                    receipt.toggleSettled(item)
                    afterSettlementChange()
                } label: {
                    if item.paid {
                        Label("Receipt.Item.Settle.ClearAll", systemImage: "arrow.uturn.backward")
                    } else {
                        Label("Receipt.Item.Settle.MarkAllPaid", systemImage: "checkmark.circle")
                    }
                }
            } label: {
                settlementRowLabel(for: item)
            }
        }
    }

    @ViewBuilder
    func settlementRowLabel(for item: ReceiptItem) -> some View {
        HStack(alignment: .center, spacing: 8.0) {
            ReceiptItemRow(name: item.name, price: item.price)
                .strikethrough(item.paid)
                .multilineTextAlignment(.leading)
            if item.person == nil {
                let paidCount = sharedPaidCount(for: item)
                let total = receipt.participants().count
                if paidCount > 0 && !item.paid {
                    Text(verbatim: "\(paidCount)/\(total)")
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text(settledCountAccessibility(paid: paidCount, total: total)))
                }
            }
        }
    }

    func sharedPaidCount(for item: ReceiptItem) -> Int {
        let participantIDs = Set(receipt.participants().map { $0.id })
        let paidIDs = Set((item.peopleWhoPaid ?? []).map { $0.id })
        return participantIDs.intersection(paidIDs).count
    }

    func settledCountAccessibility(paid: Int, total: Int) -> String {
        NSLocalizedString("Receipt.Item.SettledCount", comment: "")
            .replacingOccurrences(of: "%1", with: String(paid))
            .replacingOccurrences(of: "%2", with: String(total))
    }

    func reassign(_ item: ReceiptItem, to person: Person?) {
        receipt.reassign(item, to: person, markSelfPaid: markSelfPaid)
        try? modelContext.save()
        afterSettlementChange()
    }

    func afterSettlementChange() {
        DuesApp.reloadWidget()
        if receipt.isPaid() {
            confettiCounter += 1
        }
    }

    @ViewBuilder
    func receiptDetailsForExport() -> some View {
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
            if !receipt.items().isEmpty {
                Divider()
                Text(NSLocalizedString("Receipt.PurchasedItems", comment: ""))
                    .font(.system(size: 28.0))
                    .bold()
                ForEach(receipt.items()) { item in
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
            if !receipt.discountItems().isEmpty {
                Divider()
                Text(NSLocalizedString("Receipt.Discounts", comment: ""))
                    .font(.system(size: 28.0))
                    .bold()
                ForEach(receipt.discountItems()) { item in
                    ReceiptItemRow(name: item.name, price: item.price, priceFont: .system(size: 16.0))
                }
            }
            if !receipt.taxItems().isEmpty {
                Divider()
                Text(NSLocalizedString("Receipt.Taxes", comment: ""))
                    .font(.system(size: 28.0))
                    .bold()
                ForEach(receipt.taxItems()) { item in
                    ReceiptItemRow(name: item.name, price: item.price, priceFont: .system(size: 16.0))
                }
            }
            Divider()
            HStack(alignment: .center, spacing: 4.0) {
                Text(NSLocalizedString("Receipt.Total.BeforeTax", comment: ""))
                Spacer()
                Text(format(receipt.sumOfItems()))
                    .monospaced()
            }
            HStack(alignment: .center, spacing: 4.0) {
                Text(NSLocalizedString("Receipt.Total.AfterTax", comment: ""))
                Spacer()
                Text(format(receipt.sum()))
                    .monospaced()
            }
            .bold()
        }
        .font(.system(size: 16.0))
        .padding()
        .foregroundStyle(.primary)
        .background(.background)
    }
    // swiftlint:enable function_body_length

    var shareSignature: String {
        let items = receipt.items().map { "\($0.id):\($0.price):\($0.paid)" }.joined(separator: ",")
        return "\(receipt.name)|\(items)|\(receipt.discountItems().count)|\(receipt.taxItems().count)|\(receipt.sum())"
    }

    @MainActor
    func createImageToShare() -> Image {
        let renderer = ImageRenderer(content: receiptDetailsForExport())
        renderer.scale = 3.0
        if let image = renderer.cgImage {
            return Image(uiImage: UIImage(cgImage: image))
        }
        // Degrade gracefully instead of crashing if rendering fails.
        return Image(systemName: "doc.richtext")
    }

    func createTextToShare() -> String {
        var lines: [String] = []
        lines.append(receipt.name)
        lines.append(String(repeating: "-", count: 30))
        if let personWhoPaid = receipt.personWhoPaid {
            lines.append("\(NSLocalizedString("Receipt.Payer", comment: "")): \(personWhoPaid.name)")
            lines.append("")
        }
        if !receipt.items().isEmpty {
            lines.append(NSLocalizedString("Receipt.PurchasedItems", comment: ""))
            for item in receipt.items() {
                let assignee = item.person?.name ?? NSLocalizedString("Shared.Shared", comment: "")
                lines.append("  \(item.name) - \(format(item.price)) [\(assignee)]")
            }
            lines.append("")
        }
        if !receipt.discountItems().isEmpty {
            lines.append(NSLocalizedString("Receipt.Discounts", comment: ""))
            for item in receipt.discountItems() {
                lines.append("  \(item.name) - \(format(item.price))")
            }
            lines.append("")
        }
        if !receipt.taxItems().isEmpty {
            lines.append(NSLocalizedString("Receipt.Taxes", comment: ""))
            for item in receipt.taxItems() {
                lines.append("  \(item.name) - \(format(item.price))")
            }
            lines.append("")
        }
        lines.append(String(repeating: "-", count: 30))
        lines.append("\(NSLocalizedString("Receipt.Total.BeforeTax", comment: "")): \(format(receipt.sumOfItems()))")
        lines.append("\(NSLocalizedString("Receipt.Total.AfterTax", comment: "")): \(format(receipt.sum()))")
        return lines.joined(separator: "\n")
    }
}
// swiftlint:enable type_body_length
