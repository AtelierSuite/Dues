import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct ReceiptItemsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.tsubuzaki.Meloan.ReceiptItemsWidget",
                               intent: ReceiptIntent.self,
                               provider: Provider()) { entry in
            ReceiptItemsWidgetView(entry: entry)
                .containerBackground(.widgetBackground, for: .widget)
        }
        .configurationDisplayName("Widget.ReceiptItems.Title")
        .description("Widget.ReceiptItems.Description")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ReceiptItemsWidgetView: View {

    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            if let receipt = entry.receipt {
                switch family {
                case .systemLarge:
                    HStack(alignment: .center, spacing: 8.0) {
                        Text(receipt.name)
                            .font(.system(size: 17.0))
                            .bold()
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(receipt.isPaid() ? LocalizedStringKey("Widget.Paid.Yes") :
                                LocalizedStringKey("Widget.Paid.No"))
                        .textCase(.uppercase)
                        .foregroundStyle(.white)
                        .font(.system(size: 15.0))
                        .bold()
                        .padding([.leading, .trailing], 4.0)
                        .padding([.top, .bottom], 2.0)
                        .background(receipt.isPaid() ? Color.green : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8.0))
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 8.0) {
                        ForEach((receipt.receiptItems ?? [])
                            .sorted(by: { $0.dateAdded < $1.dateAdded })
                            .prefix(7)) { item in
                            Button(intent: TogglePaidIntent(id: item.id)) {
                                ReceiptItemWidgetRow(isShared: item.person == nil,
                                                     photoData: item.person?.photo,
                                                     name: item.name,
                                                     price: item.price)
                                    .strikethrough(item.paid)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 0)
                    Divider()
                    HStack(alignment: .center, spacing: 8.0) {
                        Text("Widget.Total.Large")
                        Spacer()
                        Text(format(receipt.sum()))
                    }
                    .font(.system(size: 14.0))
                    .monospaced()
                default:
                    GeometryReader { metrics in
                        HStack(alignment: .top, spacing: 8.0) {
                            VStack(alignment: .leading, spacing: 4.0) {
                                Text(receipt.name)
                                    .font(.system(size: 17.0))
                                    .bold()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                Text(receipt.isPaid() ? LocalizedStringKey("Widget.Paid.Yes") :
                                        LocalizedStringKey("Widget.Paid.No"))
                                .textCase(.uppercase)
                                .foregroundStyle(.white)
                                .font(.system(size: 15.0))
                                .bold()
                                .padding([.leading, .trailing], 4.0)
                                .padding([.top, .bottom], 2.0)
                                .background(receipt.isPaid() ? Color.green : Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 8.0))
                            }
                            .compositingGroup()
                            .frame(width: metrics.size.width / 3)
                            Divider()
                            VStack(alignment: .leading, spacing: 8.0) {
                                ForEach(receipt.items()
                                    .prefix(4)) { item in
                                        Button(intent: TogglePaidIntent(id: item.id)) {
                                            ReceiptItemWidgetRow(isShared: item.person == nil,
                                                                 photoData: item.person?.photo,
                                                                 name: item.name,
                                                                 price: item.price)
                                            .strikethrough(item.paid)
                                        }
                                        .buttonStyle(.plain)
                                    }
                            }
                        }
                    }
                }
            } else {
                NoReceiptHintView()
            }
        }
    }
}

struct ReceiptItemWidgetRow: View {

    var isShared: Bool
    var photoData: Data?
    var name: String
    var price: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            HStack(alignment: .center, spacing: 8.0) {
                Group {
                    if isShared {
                        Image("Profile.Shared.Circle")
                            .resizable()
                    } else {
                        if let photoData = photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                        } else {
                            Image("Profile.Generic.Circle")
                                .resizable()
                        }
                    }
                }
                .frame(width: 16.0, height: 16.0)
                .clipShape(Circle())
                Text(name)
                Spacer()
                Text(format(price))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 14.0))
            .monospaced()
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            Divider()
        }
    }
}
