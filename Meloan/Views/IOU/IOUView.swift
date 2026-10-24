import Komponents
import SwiftData
import SwiftUI
import TipKit

enum IOUViewMode: String, CaseIterable {
    case byPerson = "IOU.ViewMode.ByPerson"
    case byReceipt = "IOU.ViewMode.ByReceipt"
    case byLender = "IOU.ViewMode.ByLender"
}

// swiftlint:disable type_body_length
struct IOUView: View {

    @EnvironmentObject var navigationManager: NavigationManager
    @Query(sort: \Person.name) var people: [Person]
    @Query var receipts: [Receipt]
    @State var personWhoPaid: Person?
    @State var isInitialLoadCompleted: Bool = false
    @State var viewMode: IOUViewMode = .byPerson

    var body: some View {
        NavigationStack(path: $navigationManager.iouTabPath) {
            VStack(alignment: .leading, spacing: 0.0) {
                TipView(IOUTip())
                    .padding(20.0)
                if personWhoPaid != nil {
                    Picker("IOU.ViewMode", selection: $viewMode) {
                        ForEach(IOUViewMode.allCases, id: \.self) { mode in
                            Text(LocalizedStringKey(mode.rawValue))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20.0)
                    .padding(.bottom, 8.0)
                    summaryBanner()
                }
                Group {
                    switch viewMode {
                    case .byPerson:
                        iouByPersonView()
                    case .byReceipt:
                        iouByReceiptView()
                    case .byLender:
                        iouByLenderView()
                    }
                }
                .listStyle(.sidebar)
                .overlay {
                    if personWhoPaid == nil {
                        HintOverlay(image: "filemenu.and.selection", text: "IOU.Hint")
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0.0) {
                    Picker(selection: $personWhoPaid) {
                        Text("Shared.NoSelection")
                            .tag(nil as Person?)
                        if let mePerson = people.first(where: { $0.id == "ME" }) {
                            PersonRow(person: mePerson)
                                .tag(mePerson as Person?)
                        }
                        ForEach(people.filter({ $0.id != "ME" })) { person in
                            PersonRow(person: person)
                                .tag(person as Person?)
                        }
                    } label: {
                        Text(viewMode == .byLender ? "IOU.SelectBorrower" : "IOU.SelectLender")
                            .tint(.primary)
                            .bold()
                    }
                    .pickerStyle(.navigationLink)
                    .padding()
                    .background(.regularMaterial)
                }
            }
            .navigationTitle("ViewTitle.IOU")
            .onAppear {
                if !isInitialLoadCompleted {
                    personWhoPaid = people.first(where: { $0.id == "ME" })
                    isInitialLoadCompleted = true
                }
            }
        }
    }

    @ViewBuilder
    func summaryBanner() -> some View {
        if let personWhoPaid = personWhoPaid {
            let total = grandTotal(for: personWhoPaid)
            if total > 0 {
                HStack(alignment: .center, spacing: 8.0) {
                    Text(viewMode == .byLender ? "IOU.Summary.TotalYouOwe" : "IOU.Summary.TotalOwedToYou")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(format(total))
                        .font(.subheadline)
                        .monospaced()
                        .bold()
                }
                .padding(.horizontal, 20.0)
                .padding(.bottom, 8.0)
            }
        }
    }

    func grandTotal(for selected: Person) -> Double {
        switch viewMode {
        case .byLender:
            return people.reduce(0.0) { partial, lender in
                lender.id == selected.id ? partial : partial + selected.sumOwed(to: lender)
            }
        default:
            return people.reduce(0.0) { partial, borrower in
                borrower.id == selected.id ? partial : partial + borrower.sumOwed(to: selected)
            }
        }
    }

    @ViewBuilder
    func iouByPersonView() -> some View {
        List(people) { person in
            if let personWhoPaid = self.personWhoPaid, !(personWhoPaid.receiptsPaid?.isEmpty ?? true) {
                if person.id != personWhoPaid.id && person.sumOwed(to: personWhoPaid) != .zero {
                    Section {
                        // IMPORTANT: Do NOT refactor anything here! SwiftUI will reuse views in an unexpected
                        // manner, and cause totals to appear incorrectly (calculation is CORRECT).
                        ForEach(person.receiptsParticipated ?? []) { receipt in
                            if receipt.personWhoPaid == personWhoPaid {
                                HStack(alignment: .center, spacing: 4.0) {
                                    Text(receipt.name)
                                    Spacer()
                                    Text(format(receipt.sumOwed(to: personWhoPaid, for: person)))
                                        .font(.system(size: 14.0))
                                        .monospaced()
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .center, spacing: 16.0) {
                            Group {
                                if let photo = person.photo, let image = UIImage(data: photo) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image("Profile.Generic")
                                        .resizable()
                                }
                            }
                            .frame(width: 30.0, height: 30.0)
                            .clipShape(Circle())
                            Text(verbatim: person.name)
                                .bold()
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .allowsTightening(true)
                                .font(.body)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = format(person.sumOwed(to: personWhoPaid))
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20.0, height: 20.0)
                            }
                            .accessibilityLabel(Text("Shared.CopyAmount"))
                            ShareLink(item: hey(person, youOweMe: person.sumOwed(to: personWhoPaid))) {
                                Image(systemName: "square.and.arrow.up")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24.0, height: 24.0)
                            }
                            .accessibilityLabel(Text("Shared.SendReminder"))
                        }
                        .listRowInsets(EdgeInsets(top: 16.0, leading: 0.0, bottom: 8.0, trailing: 0.0))
                    } footer: {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("IOU.TotalBorrowed")
                                .font(.body)
                            Spacer()
                            Text(format(person.sumOwed(to: personWhoPaid)))
                                .font(.system(size: 14.0))
                                .monospaced()
                        }
                        .bold()
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func iouByReceiptView() -> some View {
        List(receipts) { receipt in
            if let personWhoPaid = self.personWhoPaid, receipt.personWhoPaid == personWhoPaid {
                let borrowers = receipt.borrowers().filter { receipt.sumOwed(to: personWhoPaid, for: $0) > 0 }
                if !borrowers.isEmpty {
                    Section {
                        ForEach(borrowers) { borrower in
                            HStack(alignment: .center, spacing: 8.0) {
                                Group {
                                    if let photo = borrower.photo, let image = UIImage(data: photo) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image("Profile.Generic")
                                            .resizable()
                                    }
                                }
                                .frame(width: 24.0, height: 24.0)
                                .clipShape(Circle())
                                Text(borrower.name)
                                Spacer()
                                Text(format(receipt.sumOwed(to: personWhoPaid, for: borrower)))
                                    .font(.system(size: 14.0))
                                    .monospaced()
                            }
                        }
                    } header: {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text(receipt.name)
                                .bold()
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .font(.body)
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets(top: 16.0, leading: 0.0, bottom: 8.0, trailing: 0.0))
                    } footer: {
                        let totalOwed = borrowers.reduce(0.0) { $0 + receipt.sumOwed(to: personWhoPaid, for: $1) }
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("IOU.TotalBorrowed")
                                .font(.body)
                            Spacer()
                            Text(format(totalOwed))
                                .font(.system(size: 14.0))
                                .monospaced()
                        }
                        .bold()
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func iouByLenderView() -> some View {
        // "By Lender" mode: selected person is the borrower, show what they owe to each lender
        List(people) { lender in
            if let selectedBorrower = self.personWhoPaid, !(lender.receiptsPaid?.isEmpty ?? true) {
                if lender.id != selectedBorrower.id && selectedBorrower.sumOwed(to: lender) != .zero {
                    Section {
                        ForEach(selectedBorrower.receiptsParticipated ?? []) { receipt in
                            if receipt.personWhoPaid == lender {
                                HStack(alignment: .center, spacing: 4.0) {
                                    Text(receipt.name)
                                    Spacer()
                                    Text(format(receipt.sumOwed(to: lender, for: selectedBorrower)))
                                        .font(.system(size: 14.0))
                                        .monospaced()
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .center, spacing: 16.0) {
                            Group {
                                if let photo = lender.photo, let image = UIImage(data: photo) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    Image("Profile.Generic")
                                        .resizable()
                                }
                            }
                            .frame(width: 30.0, height: 30.0)
                            .clipShape(Circle())
                            Text(verbatim: lender.name)
                                .bold()
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .allowsTightening(true)
                                .font(.body)
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets(top: 16.0, leading: 0.0, bottom: 8.0, trailing: 0.0))
                    } footer: {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("IOU.TotalOwed")
                                .font(.body)
                            Spacer()
                            Text(format(selectedBorrower.sumOwed(to: lender)))
                                .font(.system(size: 14.0))
                                .monospaced()
                        }
                        .bold()
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}
// swiftlint:enable type_body_length
