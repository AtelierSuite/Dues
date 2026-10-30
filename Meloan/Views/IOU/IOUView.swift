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
    @ScaledMetric var copyIconSize: CGFloat = 20.0
    @ScaledMetric var shareIconSize: CGFloat = 24.0

    var body: some View {
        NavigationStack(path: $navigationManager.iouTabPath) {
            // What each person owes (or, by lender, is owed), computed once per update.
            let amounts = personWhoPaid.map { owedAmounts(for: $0) } ?? [:]
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
                    summaryBanner(total: amounts.values.reduce(0.0, +))
                }
                Group {
                    switch viewMode {
                    case .byPerson:
                        iouByPersonView(amounts: amounts)
                    case .byReceipt:
                        iouByReceiptView()
                    case .byLender:
                        iouByLenderView(amounts: amounts)
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
    func summaryBanner(total: Double) -> some View {
        if personWhoPaid != nil {
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

    /// By lender, what the selected person owes each lender; otherwise, what each borrower
    /// owes the selected person.
    func owedAmounts(for selected: Person) -> [PersistentIdentifier: Double] {
        var amounts: [PersistentIdentifier: Double] = [:]
        for person in people where person.id != selected.id {
            amounts[person.persistentModelID] = viewMode == .byLender ?
                selected.sumOwed(to: person) : person.sumOwed(to: selected)
        }
        return amounts
    }

    @ViewBuilder
    func iouByPersonView(amounts: [PersistentIdentifier: Double]) -> some View {
        List(people) { person in
            let amountOwed = amounts[person.persistentModelID] ?? .zero
            if let personWhoPaid = self.personWhoPaid, !(personWhoPaid.receiptsPaid?.isEmpty ?? true) {
                if person.id != personWhoPaid.id && amountOwed != .zero {
                    Section {
                        // IMPORTANT: Do NOT refactor anything here! SwiftUI will reuse views in an unexpected
                        // manner, and cause totals to appear incorrectly (calculation is CORRECT).
                        ForEach(person.receiptsParticipated ?? []) { receipt in
                            if receipt.personWhoPaid == personWhoPaid {
                                HStack(alignment: .center, spacing: 4.0) {
                                    Text(receipt.name)
                                    Spacer()
                                    Text(format(receipt.sumOwed(to: personWhoPaid, for: person)))
                                        .font(.subheadline)
                                        .monospaced()
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .center, spacing: 16.0) {
                            PersonAvatar(person: person, size: 30.0)
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
                                UIPasteboard.general.string = format(amountOwed)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: copyIconSize, height: copyIconSize)
                            }
                            .accessibilityLabel(Text("Shared.CopyAmount"))
                            ShareLink(item: hey(person, youOweMe: amountOwed)) {
                                Image(systemName: "square.and.arrow.up")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: shareIconSize, height: shareIconSize)
                            }
                            .accessibilityLabel(Text("Shared.SendReminder"))
                        }
                        .listRowInsets(EdgeInsets(top: 16.0, leading: 0.0, bottom: 8.0, trailing: 0.0))
                    } footer: {
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("IOU.TotalBorrowed")
                                .font(.body)
                            Spacer()
                            Text(format(amountOwed))
                                .font(.subheadline)
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
                let overallRate = receipt.overallRate()
                let amountsOwed = receipt.borrowers()
                    .map { (borrower: $0, amount: receipt.sumOwed(to: personWhoPaid, for: $0,
                                                                  overallRate: overallRate)) }
                    .filter { $0.amount > 0 }
                if !amountsOwed.isEmpty {
                    Section {
                        ForEach(amountsOwed, id: \.borrower.id) { borrower, amount in
                            HStack(alignment: .center, spacing: 8.0) {
                                PersonAvatar(person: borrower, size: 24.0)
                                Text(borrower.name)
                                Spacer()
                                Text(format(amount))
                                    .font(.subheadline)
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
                        let totalOwed = amountsOwed.reduce(0.0) { $0 + $1.amount }
                        HStack(alignment: .center, spacing: 8.0) {
                            Text("IOU.TotalBorrowed")
                                .font(.body)
                            Spacer()
                            Text(format(totalOwed))
                                .font(.subheadline)
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
    func iouByLenderView(amounts: [PersistentIdentifier: Double]) -> some View {
        // "By Lender" mode: selected person is the borrower, show what they owe to each lender
        List(people) { lender in
            let amountOwed = amounts[lender.persistentModelID] ?? .zero
            if let selectedBorrower = self.personWhoPaid, !(lender.receiptsPaid?.isEmpty ?? true) {
                if lender.id != selectedBorrower.id && amountOwed != .zero {
                    Section {
                        ForEach(selectedBorrower.receiptsParticipated ?? []) { receipt in
                            if receipt.personWhoPaid == lender {
                                HStack(alignment: .center, spacing: 4.0) {
                                    Text(receipt.name)
                                    Spacer()
                                    Text(format(receipt.sumOwed(to: lender, for: selectedBorrower)))
                                        .font(.subheadline)
                                        .monospaced()
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .center, spacing: 16.0) {
                            PersonAvatar(person: lender, size: 30.0)
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
                            Text(format(amountOwed))
                                .font(.subheadline)
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
