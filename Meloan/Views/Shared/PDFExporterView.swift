import Komponents
import PDFKit
import QuickLook
import SwiftUI

struct PDFExporterView: View {

    @Environment(\.dismiss) var dismiss
    var receipt: Receipt
    @State var pdfFile: PDFDocument?

    var body: some View {
        NavigationStack {
            if let pdfFile = pdfFile {
                PDFKitView(document: pdfFile)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            CloseButton {
                                dismiss()
                            }
                        }
                        ToolbarItem(placement: .bottomBar) {
                            HStack {
                                Spacer()
                                ShareLink(item: pdfFile, preview: SharePreview(receipt.name, image: pdfFile)) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                    .navigationTitle("Shared.PDFExport")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            let pdfData = ReceiptPDFRenderer(receipt: receipt).render()
            pdfFile = PDFDocument(data: pdfData)
        }
    }
}
