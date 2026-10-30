import Komponents
import SwiftData
import SwiftUI
import UIKit

// swiftlint:disable type_body_length file_length
struct ReceiptEditor: View {

    @Environment(\.modelContext) var modelContext
    @Environment(\.undoManager) var undoManager
    @Environment(\.dismiss) var dismiss
    @AppStorage(wrappedValue: true, "MarkSelfPaid", store: defaults) var markSelfPaid: Bool
    @AppStorage(wrappedValue: 0.0, "TaxRate", store: defaults) var taxRate: Double
    @AppStorage(wrappedValue: "", "TaxRateCountry", store: defaults) var taxRateCountry: String
    @AppStorage(wrappedValue: "", "TaxRateType", store: defaults) var taxRateType: String
    @AppStorage(wrappedValue: false, "AddTenPercent", store: defaults) var addTenPercent: Bool
    @AppStorage(wrappedValue: false, "TaxAboveServiceCharge", store: defaults) var taxAboveServiceCharge: Bool
    @State var isPersonPickerPresented: Bool = false
    @State var isSaveConfirmed: Bool = false
    @State private var isSaveErrorPresented: Bool = false
    @State private var saveErrorMessage: String = ""
    @State var draft: ReceiptDraft
    var receipt: Receipt
    var isNewReceipt: Bool = false

    init(receipt: Receipt, isNewReceipt: Bool = false) {
        self.receipt = receipt
        self.isNewReceipt = isNewReceipt
        self._draft = State(initialValue: ReceiptDraft(from: receipt))
    }

    var body: some View {
        let participants = draft.participants()
        List {
            Section {
                TextField("Receipt.Name", text: $draft.name)
                    .textInputAutocapitalization(.words)
            }
            Section {
                Button {
                    isPersonPickerPresented = true
                } label: {
                    HStack {
                        Text("Receipt.Participants")
                            .bold()
                            .tint(.primary)
                        Spacer()
                        Text(NSLocalizedString("Receipt.Participants.Label", comment: "")
                            .replacingOccurrences(of: "%1", with: String(participants.count)))
                        .lineLimit(1)
                        .truncationMode(.head)
                    }
                }
                .sheet(isPresented: $isPersonPickerPresented) {
                    NavigationStack {
                        PeoplePicker(title: "Receipt.Participants", selection: $draft.peopleWhoParticipated)
                            .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium])
                }
                Picker(selection: $draft.personWhoPaid) {
                    Text("Shared.NoSelection")
                        .tag(nil as Person?)
                    ForEach(participants) { person in
                        PersonRow(person: person)
                            .tag(person as Person?)
                    }
                } label: {
                    Text("Receipt.Payer")
                        .bold()
                }
                .pickerStyle(.navigationLink)
            } footer: {
                Text("Receipt.Participants.Description")
                    .font(.subheadline)
            }
            Section {
                ForEach($draft.receiptItems) { $item in
                    ReceiptItemAssignableRow(item: $item,
                                             peopleWhoParticipated: participants,
                                             placeholderText: "Receipt.ProductName")
                }
                .onDelete { indexSet in
                    draft.receiptItems.remove(atOffsets: indexSet)
                }
            } header: {
                HStack(alignment: .center, spacing: 4.0) {
                    ListSectionHeader(text: "Receipt.PurchasedItems")
                        .font(.body)
                    Spacer()
                    Button {
                        draft.receiptItems.append(
                            ReceiptDraft.Item(id: UUID().uuidString, name: "", price: 0.0,
                                              person: nil, dateAdded: Date.now))
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            Section {
                ForEach($draft.discountItems) { $item in
                    ReceiptItemEditableRow(item: $item,
                                           placeholderText: "Receipt.ItemName")
                }
                .onDelete { indexSet in
                    draft.discountItems.remove(atOffsets: indexSet)
                }
            } header: {
                HStack(alignment: .center, spacing: 4.0) {
                    ListSectionHeader(text: "Receipt.Discounts")
                        .font(.body)
                    Spacer()
                    Button {
                        draft.discountItems.append(
                            ReceiptDraft.Discount(id: UUID().uuidString, name: "", price: 0.0,
                                                  dateAdded: Date.now))
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            if draft.taxItems.isEmpty && taxRateCountry != "" {
                Section {
                    Text("Receipt.Tax.AutomaticallyCalculatedHint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } header: {
                    HStack(alignment: .center, spacing: 4.0) {
                        ListSectionHeader(text: "Receipt.Taxes")
                            .font(.body)
                        Spacer()
                        tipMenu
                    }
                }
            } else {
                Section {
                    ForEach($draft.taxItems) { $item in
                        ReceiptItemEditableRow(item: $item,
                                               placeholderText: "Receipt.ItemName")
                    }
                    .onDelete { indexSet in
                        draft.taxItems.remove(atOffsets: indexSet)
                    }
                } header: {
                    HStack(alignment: .center, spacing: 4.0) {
                        ListSectionHeader(text: "Receipt.Taxes")
                            .font(.body)
                        Spacer()
                        tipMenu
                        Button {
                            draft.taxItems.append(
                                ReceiptDraft.Tax(id: UUID().uuidString, name: "", price: 0.0,
                                                 dateAdded: Date.now))
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                    }
                } footer: {
                    if draftHasManualTax && autoChargesConfigured {
                        Text("Receipt.Tax.ManualOverridesAutoHint")
                            .font(.subheadline)
                    } else if taxRateCountry != "" && draft.taxItems.allSatisfy({ Gratuity.isTip(id: $0.id) }) {
                        // Only a tip so far: the automatic tax is still added on save.
                        Text("Receipt.Tax.AutomaticallyCalculatedHint")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                cancelButton
            }
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarLeading)
            }
            ToolbarItemGroup(placement: .topBarLeading) {
                Button {
                    undoManager?.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!(undoManager?.canUndo ?? false))
                Button {
                    undoManager?.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!(undoManager?.canRedo ?? false))
            }
            ToolbarItem(placement: .confirmationAction) {
                saveButton
            }
        }
        .sensoryFeedback(.success, trigger: isSaveConfirmed)
        .interactiveDismissDisabled()
        .alert("Alert.SaveFailed.Title", isPresented: $isSaveErrorPresented) {
            Button("Shared.OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage.isEmpty ?
                 NSLocalizedString("Alert.SaveFailed.Message", comment: "") : saveErrorMessage)
        }
        .onChange(of: draft.name) { oldValue, newValue in
            registerUndo(\.name, from: oldValue, to: newValue)
        }
        .onChange(of: draft.personWhoPaid) { oldValue, newValue in
            registerUndo(\.personWhoPaid, from: oldValue, to: newValue)
        }
        .onChange(of: draft.peopleWhoParticipated) { oldValue, newValue in
            registerUndo(\.peopleWhoParticipated, from: oldValue, to: newValue)
            if !draft.isApplyingUndoRedo, let personWhoPaid = draft.personWhoPaid {
                if !draft.participants().contains(where: { $0.id == personWhoPaid.id }) {
                    draft.personWhoPaid = nil
                }
            }
        }
        .onChange(of: draft.receiptItems) { oldValue, newValue in
            registerUndo(\.receiptItems, from: oldValue, to: newValue)
        }
        .onChange(of: draft.discountItems) { oldValue, newValue in
            registerUndo(\.discountItems, from: oldValue, to: newValue)
        }
        .onChange(of: draft.taxItems) { oldValue, newValue in
            registerUndo(\.taxItems, from: oldValue, to: newValue)
        }
    }

    var tipMenu: some View {
        ReceiptTipMenu(taxItems: $draft.taxItems,
                       subtotal: draft.sumOfItems() - draft.sumOfDiscounts(),
                       totalBeforeTip: totalBeforeTip)
    }

    /// What the receipt will total once saved, before any tip: items less discounts plus
    /// the user's own tax lines, or else the automatic charges `saveEditing()` will add.
    var totalBeforeTip: Double {
        let manualTax = draft.taxItems
            .filter { isManualTax(id: $0.id) }
            .reduce(0.0) { $0 + $1.price }
        var total = draft.sumOfItems() - draft.sumOfDiscounts() + manualTax
        if !draftHasManualTax {
            let autoCharges = autoCharges(sumOfItems: draft.sumOfItems(), hasManualTax: false)
            total += (autoCharges.serviceCharge ?? 0.0) + (autoCharges.tax ?? 0.0)
        }
        return total
    }

    /// Registers an undo that restores `keyPath` to `oldValue`, unless the change
    /// itself came from an undo/redo (which would corrupt the undo stack).
    func registerUndo<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<ReceiptDraft, T>,
                                    from oldValue: T, to newValue: T) {
        guard oldValue != newValue, !draft.isApplyingUndoRedo else { return }
        undoManager?.registerUndo(withTarget: draft) { draft in
            draft.isApplyingUndoRedo = true
            draft[keyPath: keyPath] = oldValue
            DispatchQueue.main.async { draft.isApplyingUndoRedo = false }
        }
    }

    @ViewBuilder var cancelButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .cancel) {
                cancelEditing()
            }
        } else {
            Button("Shared.Cancel") {
                cancelEditing()
            }
        }
    }

    @ViewBuilder var saveButton: some View {
        if #available(iOS 26.0, *) {
            Button(role: .confirm) {
                saveEditing()
            }
        } else {
            Button("Shared.Save") {
                saveEditing()
            }
        }
    }

    func cancelEditing() {
        if isNewReceipt {
            modelContext.delete(receipt)
            try? modelContext.save()
        } else {
            // Discard unsaved edits from a failed save attempt.
            modelContext.rollback()
        }
        dismiss()
    }

    // swiftlint:disable function_body_length cyclomatic_complexity
    func saveEditing() {
        // Re-insert if a previous failed save rolled the context back.
        if isNewReceipt && receipt.modelContext == nil {
            modelContext.insert(receipt)
        }
        // Apply draft data to the model
        let previousPayerID = receipt.personWhoPaid?.id
        receipt.name = draft.name
        receipt.personWhoPaid = draft.personWhoPaid
        receipt.peopleWhoParticipated = draft.peopleWhoParticipated

        // Sync receipt items
        let existingItems = receipt.items(sorted: false)
        let draftItemIDs = Set(draft.receiptItems.map { $0.id })
        for existingItem in existingItems where !draftItemIDs.contains(existingItem.id) {
            receipt.receiptItems?.removeAll { $0.id == existingItem.id }
            modelContext.delete(existingItem)
        }
        for draftItem in draft.receiptItems {
            if let existingItem = existingItems.first(where: { $0.id == draftItem.id }) {
                existingItem.name = draftItem.name
                existingItem.price = draftItem.price
                existingItem.person = draftItem.person
            } else {
                let newItem = ReceiptItem(name: draftItem.name, price: draftItem.price, amount: 1)
                newItem.id = draftItem.id
                newItem.person = draftItem.person
                receipt.addReceiptItems(from: [newItem])
            }
        }

        // Sync discount items
        var existingDiscounts: [String: DiscountItem] = [:]
        for existingDiscount in receipt.discountItems(sorted: false) {
            if existingDiscounts[existingDiscount.id] == nil {
                existingDiscounts[existingDiscount.id] = existingDiscount
            } else {
                // A legacy duplicate ID (see ReceiptDraft); its draft row is re-added below.
                receipt.discountItems?.removeAll { $0 === existingDiscount }
                modelContext.delete(existingDiscount)
            }
        }
        let draftDiscountIDs = Set(draft.discountItems.map { $0.id })
        for (id, existingDiscount) in existingDiscounts where !draftDiscountIDs.contains(id) {
            receipt.discountItems?.removeAll { $0 === existingDiscount }
            modelContext.delete(existingDiscount)
        }
        for draftDiscount in draft.discountItems {
            if let existingDiscount = existingDiscounts[draftDiscount.id] {
                existingDiscount.name = draftDiscount.name
                existingDiscount.price = draftDiscount.price
            } else {
                let newDiscount = DiscountItem(name: draftDiscount.name, price: draftDiscount.price)
                newDiscount.id = draftDiscount.id
                newDiscount.dateAdded = draftDiscount.dateAdded
                receipt.addDiscountItems(from: [newDiscount])
            }
        }

        // Sync tax items
        let existingTaxes = receipt.taxItems(sorted: false)
        let draftTaxIDs = Set(draft.taxItems.map { $0.id })
        for existingTax in existingTaxes where !draftTaxIDs.contains(existingTax.id) {
            receipt.taxItems?.removeAll { $0.id == existingTax.id }
            modelContext.delete(existingTax)
        }
        for draftTax in draft.taxItems {
            if let existingTax = existingTaxes.first(where: { $0.id == draftTax.id }) {
                existingTax.name = draftTax.name
                existingTax.price = draftTax.price
            } else {
                let newTax = TaxItem(name: draftTax.name, price: draftTax.price)
                newTax.id = draftTax.id
                receipt.addTaxItems(from: [newTax])
            }
        }

        // Honor the MarkSelfPaid setting on first creation or whenever the payer
        // changes, but skip it when the payer is unchanged so manual paid/unpaid
        // toggles made on an existing receipt are never silently overwritten.
        let payerChanged = previousPayerID != receipt.personWhoPaid?.id
        if markSelfPaid && (isNewReceipt || payerChanged) {
            receipt.setLenderItemsPaid()
        }
        // Keep shared items' paid flags consistent with the edited participant list.
        let participantIDs = Set(receipt.participants().map { $0.id })
        for item in receipt.receiptItems ?? [] where item.person == nil {
            item.refreshSharedPaidState(participantIDs: participantIDs)
        }
        // Auto charges are suppressed when the user supplied their own tax (no double tax).
        let hasManualTax = receipt.taxItems?.contains(where: { isManualTax(id: $0.id) }) ?? false
        let autoCharges = autoCharges(sumOfItems: receipt.sumOfItems(), hasManualTax: hasManualTax)
        let serviceChargeID = AutoCharges.serviceChargeID(for: receipt.id)
        if let serviceChargeAmount = autoCharges.serviceCharge {
            if let serviceChargeItem = receipt.taxItems?.first(where: { $0.id == serviceChargeID }) {
                serviceChargeItem.price = serviceChargeAmount
            } else {
                let automaticServiceCharge = TaxItem(name: NSLocalizedString("Receipt.ServiceCharge", comment: ""),
                                                     price: serviceChargeAmount)
                automaticServiceCharge.id = serviceChargeID
                receipt.addTaxItems(from: [automaticServiceCharge])
            }
        } else {
            // Service charge off, or the user supplied their own — remove any stale auto item.
            removeAutoTaxItem(withID: serviceChargeID)
        }
        let taxID = AutoCharges.taxID(for: receipt.id)
        if let taxAmount = autoCharges.tax {
            if let taxItem = receipt.taxItems?.first(where: { $0.id == taxID }) {
                taxItem.price = taxAmount
            } else {
                let automaticTaxItem = TaxItem(name: "", price: taxAmount)
                automaticTaxItem.id = taxID
                switch taxRateType {
                case "gst":
                    automaticTaxItem.name = NSLocalizedString("Receipt.Tax.GST", comment: "")
                case "vat":
                    automaticTaxItem.name = NSLocalizedString("Receipt.Tax.VAT", comment: "")
                default:
                    automaticTaxItem.name = ""
                }
                receipt.addTaxItems(from: [automaticTaxItem])
            }
        } else {
            // Tax region cleared, or the user provided their own tax — drop the auto item.
            removeAutoTaxItem(withID: taxID)
        }
        do {
            try modelContext.save()
        } catch {
            // Discard the unsaved mutations so autosave can't persist abandoned changes.
            saveErrorMessage = error.localizedDescription
            modelContext.rollback()
            isSaveErrorPresented = true
            return
        }
        isSaveConfirmed = true
        DuesApp.reloadWidget()
        dismiss()
    }
    // swiftlint:enable function_body_length cyclomatic_complexity

    /// The draft carries at least one user-supplied (non-auto, non-tip) tax/charge line.
    /// When true, `saveEditing()` suppresses the automatic tax and service charge to
    /// avoid double-charging — surfaced to the user via a section footer.
    var draftHasManualTax: Bool {
        draft.taxItems.contains { isManualTax(id: $0.id) }
    }

    /// Whether a tax line was entered by the user. Automatic charges and tips don't count:
    /// a tip is not tax, so it never turns the automatic charges off.
    func isManualTax(id: String) -> Bool {
        !AutoCharges.isAutomatic(taxItemID: id) && !Gratuity.isTip(id: id)
    }

    /// The automatic service charge and tax for items summing to `sumOfItems`, per the
    /// user's settings. Shared by `saveEditing()` and the tip round-up preview so both
    /// agree on the total.
    func autoCharges(sumOfItems: Double, hasManualTax: Bool) -> AutoCharges {
        AutoCharges(addServiceCharge: addTenPercent, taxRateCountry: taxRateCountry,
                    taxRate: taxRate, taxAboveServiceCharge: taxAboveServiceCharge,
                    sumOfItems: sumOfItems, hasManualTax: hasManualTax)
    }

    /// Whether the user has any automatic tax/service-charge setting enabled.
    var autoChargesConfigured: Bool {
        addTenPercent || taxRateCountry != ""
    }

    func removeAutoTaxItem(withID id: String) {
        guard let item = receipt.taxItems?.first(where: { $0.id == id }) else { return }
        receipt.taxItems?.removeAll { $0.id == id }
        modelContext.delete(item)
    }
}
// swiftlint:enable type_body_length
