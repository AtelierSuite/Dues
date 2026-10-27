import AVFoundation
import Komponents
import PhotosUI
import SwiftData
import SwiftUI
import TipKit
import UIKit
import VisionKit

// swiftlint:disable type_body_length file_length
struct ReceiptsView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var toastManager: ToastManager
    @Query(sort: \Receipt.dateAdded, order: .reverse, animation: .snappy.speed(2)) var receipts: [Receipt]
    @Query(sort: \Person.name) var people: [Person]

    // State variables
    @State var receiptBeingEdited: Receipt?
    @State var isNewReceipt: Bool = false

    // Scan (OCR) flow
    @State var isScannerPresented: Bool = false
    @State var isPhotoPickerPresented: Bool = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isProcessingScan: Bool = false
    @State var isScanFailedPresented: Bool = false
    @State var isNoItemsFoundPresented: Bool = false
    @State var isCameraDeniedPresented: Bool = false

    // Filter variables
    @AppStorage(wrappedValue: false, "HidePaidReceipts", store: defaults) var hidePaid: Bool
    @AppStorage(wrappedValue: "", "FilterPayerID", store: defaults) var filterPayerID: String
    @AppStorage(wrappedValue: true, "FilterShowIPaid", store: defaults) var filterShowIPaid: Bool
    @AppStorage(wrappedValue: true, "FilterShowOthersPaid", store: defaults) var filterShowOthersPaid: Bool
    @State var filterPayer: Person?

    var body: some View {
        NavigationStack(path: $navigationManager.receiptsTabPath) {
            VStack(alignment: .leading, spacing: 0.0) {
                if receipts.count == 0 {
                    TipView(ReceiptsTip())
                        .padding(20.0)
                        .background(.background)
                }
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 20.0) {
                        ForEach(receipts) { receipt in
                            if shouldShowReceipt(receipt) {
                                VStack(alignment: .center, spacing: 16.0) {
                                    ReceiptColumn(receipt: receipt)
                                    VStack(alignment: .center, spacing: 16.0) {
                                        ActionButton(text: "Shared.Edit", icon: "Edit", isPrimary: false) {
                                            isNewReceipt = false
                                            receiptBeingEdited = receipt
                                        }
                                        ActionButton(text: "Shared.Delete", icon: "Delete", isPrimary: true) {
                                            deleteWithUndo(receipt)
                                        }
                                        .tint(.red)
                                    }
                                    .frame(width: 288.0)
                                }
                            }
                        }
                    }
                }
                .contentMargins(20.0, for: .scrollContent)
                .contentMargins(.horizontal, 20.0, for: .scrollIndicators)
                .scrollClipDisabled()
            }
            .background(Color(uiColor: UIColor.systemGroupedBackground))
            .navigationDestination(for: ViewPath.self, destination: { viewPath in
                switch viewPath {
                case .receiptDetail(let receipt): ReceiptDetailView(receipt: receipt)
                case .personDetail(let person): PeopleDetailView(person: person)
                default: Color.clear
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle(isOn: $hidePaid.animation(.snappy.speed(2))) {
                            Text("Receipts.HidePaidReceipts")
                                .bold()
                        }
                        Divider()
                        Toggle(isOn: $filterShowIPaid.animation(.snappy.speed(2))) {
                            Text("Receipts.Filter.IPaid")
                        }
                        Toggle(isOn: $filterShowOthersPaid.animation(.snappy.speed(2))) {
                            Text("Receipts.Filter.OthersPaid")
                        }
                        Divider()
                        Menu {
                            if let mePerson = people.first(where: { $0.id == "ME" }) {
                                Button {
                                    filterPayer = mePerson
                                } label: {
                                    personRowWithCheck(person: mePerson)
                                }
                            }
                            ForEach(people.filter({ $0.id != "ME" })) { person in
                                Button {
                                    filterPayer = person
                                } label: {
                                    personRowWithCheck(person: person)
                                }
                            }
                        } label: {
                            Text("Receipt.Payer")
                        }
                        Divider()
                        Button(role: .destructive) {
                            withAnimation(.snappy.speed(2)) {
                                hidePaid = false
                                filterPayer = nil
                                filterShowIPaid = true
                                filterShowOthersPaid = true
                            }
                        } label: {
                            Text("Shared.Filter.Reset")
                        }
                    } label: {
                        Label("Shared.Filter",
                              systemImage: "line.3.horizontal.decrease")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            startScan()
                        } label: {
                            Label("Receipt.Create.Scan", systemImage: "doc.text.viewfinder")
                        }
                        Button {
                            createBlankReceipt()
                        } label: {
                            Label("Receipt.Create.Manual", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Label("Shared.Create", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $receiptBeingEdited, content: { receipt in
                NavigationStack {
                    ReceiptEditor(receipt: receipt, isNewReceipt: isNewReceipt)
                }
            })
            .fullScreenCover(isPresented: $isScannerPresented) {
                ReceiptScannerView { images in
                    isScannerPresented = false
                    processScan(images)
                } onCancel: {
                    isScannerPresented = false
                } onError: { _ in
                    isScannerPresented = false
                    isScanFailedPresented = true
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                selectedPhotoItem = nil
                processPhoto(item)
            }
            .overlay {
                if isProcessingScan {
                    scanProcessingOverlay
                }
            }
            .alert("Scan.Failed.Title", isPresented: $isScanFailedPresented) {
                Button("Shared.OK", role: .cancel) { }
            } message: {
                Text("Scan.Failed.Message")
            }
            .alert("Scan.NoText.Title", isPresented: $isNoItemsFoundPresented) {
                Button("Receipt.Create.Manual") {
                    createBlankReceipt(named: NSLocalizedString("Receipt.Scan.DefaultName", comment: ""))
                }
                Button("Shared.Cancel", role: .cancel) { }
            } message: {
                Text("Scan.NoText.Message")
            }
            .alert("Scan.CameraDenied.Title", isPresented: $isCameraDeniedPresented) {
                Button("Shared.OpenSettings") { openAppSettings() }
                Button("Shared.Cancel", role: .cancel) { }
            } message: {
                Text("Scan.CameraDenied.Message")
            }
            .onAppear {
                if let filterPayer = people.first(where: { $0.id == filterPayerID }) {
                    self.filterPayer = filterPayer
                }
            }
            .onChange(of: filterPayer, { _, _ in
                filterPayerID = filterPayer?.id ?? ""
            })
            .navigationTitle("ViewTitle.Receipts")
        }
    }

    @ViewBuilder
    func personRowWithCheck(person: Person) -> some View {
        Text(person.name)
        if filterPayer == person {
            Image(systemName: "checkmark")
        } else {
            if let photo = person.photo, let image = UIImage(data: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("Profile.Generic.Circle")
                    .resizable()
            }
        }
    }

    func shouldShowReceipt(_ receipt: Receipt) -> Bool {
        // Hide paid receipts filter
        if hidePaid && receipt.isPaid() {
            return false
        }
        // Specific payer filter
        if let filterPayer = filterPayer, filterPayer != receipt.personWhoPaid {
            return false
        }
        // "I paid" / "Others paid" filter
        let mePersonID = "ME"
        let iPaid = receipt.personWhoPaid?.id == mePersonID
        if !filterShowIPaid && iPaid {
            return false
        }
        if !filterShowOthersPaid && !iPaid {
            return false
        }
        return true
    }

    // MARK: - Deletion

    func deleteWithUndo(_ receipt: Receipt) {
        // Capture the full graph before deleting so Undo can rebuild the exact receipt.
        let snapshot = ReceiptSnapshot(receipt: receipt)
        let restorePeople = people
        withAnimation(.snappy.speed(2)) {
            modelContext.delete(receipt)
        }
        try? modelContext.save()
        DuesApp.reloadWidget()
        toastManager.show(message: NSLocalizedString("Toast.ReceiptDeleted", comment: "")) {
            withAnimation(.snappy.speed(2)) {
                snapshot.restore(into: modelContext, people: restorePeople)
            }
            DuesApp.reloadWidget()
        }
    }

    // MARK: - Creation & scanning

    var scanProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 16.0) {
                ProgressView()
                    .controlSize(.large)
                Text("Scan.Processing")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(28.0)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20.0))
        }
        .accessibilityElement(children: .combine)
    }

    func createBlankReceipt(named name: String = "") {
        let receiptName = name.isEmpty ?
            NSLocalizedString("Receipt.Create.Name.Default", comment: "") : name
        let receipt = Receipt(name: receiptName)
        modelContext.insert(receipt)
        isNewReceipt = true
        receiptBeingEdited = receipt
    }

    func startScan() {
        guard VNDocumentCameraViewController.isSupported else {
            // No document camera (e.g. Simulator, Mac) — scan a photo from the library instead.
            isPhotoPickerPresented = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized, .notDetermined:
            // .notDetermined: the scanner itself triggers the system permission prompt.
            isScannerPresented = true
        case .denied, .restricted:
            isCameraDeniedPresented = true
        @unknown default:
            isScannerPresented = true
        }
    }

    func processPhoto(_ item: PhotosPickerItem) {
        isProcessingScan = true
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            await MainActor.run {
                isProcessingScan = false
                if let data, let image = UIImage(data: data) {
                    processScan([image])
                } else {
                    isScanFailedPresented = true
                }
            }
        }
    }

    func processScan(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        isProcessingScan = true
        Task {
            let rows = await ReceiptOCRService.recognizeRows(in: images)
            let parsed = ReceiptTextParser.parse(lines: rows)
            await MainActor.run {
                isProcessingScan = false
                if parsed.isEmpty {
                    isNoItemsFoundPresented = true
                } else {
                    openEditor(forScanned: parsed)
                }
            }
        }
    }

    func openEditor(forScanned parsed: ParsedReceipt) {
        let name = (parsed.merchantName?.isEmpty == false) ? parsed.merchantName! :
            NSLocalizedString("Receipt.Scan.DefaultName", comment: "")
        let receipt = Receipt(name: name)
        let items = parsed.items.map { item in
            ReceiptItem(name: item.name, price: item.price, amount: max(item.quantity, 1))
        }
        receipt.addReceiptItems(from: items)
        receipt.addTaxItems(from: parsed.taxes.map { TaxItem(name: $0.name, price: $0.price) })
        receipt.addDiscountItems(from: parsed.discounts.map { DiscountItem(name: $0.name, price: $0.price) })
        modelContext.insert(receipt)
        isNewReceipt = true
        receiptBeingEdited = receipt
    }

    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
// swiftlint:enable type_body_length
