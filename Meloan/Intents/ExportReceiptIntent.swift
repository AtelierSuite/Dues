import AppIntents
import Foundation
import UniformTypeIdentifiers

enum ReceiptExportFormat: String, AppEnum {
    case image
    case pdf

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Export Format")
    static var caseDisplayRepresentations: [ReceiptExportFormat: DisplayRepresentation] = [
        .image: "Image",
        .pdf: "PDF"
    ]
}

struct ExportReceiptIntent: AppIntent {

    static var title: LocalizedStringResource = "Export Receipt"
    static var description = IntentDescription(
        "Exports a receipt as an image or a PDF, to send or save. Long receipts are always exported as a PDF.",
        categoryName: "Sharing"
    )

    @Parameter(title: "Receipt")
    var receipt: ReceiptEntity

    @Parameter(title: "Format", default: .image)
    var format: ReceiptExportFormat

    static var parameterSummary: some ParameterSummary {
        Summary("Export \(\.$receipt) as \(\.$format)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let receipt = try IntentStore.receipt(self.receipt)
        // Slashes and colons aren't allowed in file names.
        let fileName = receipt.name.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression)
        if format == .image, ReceiptExportView.fitsInImage(receipt),
           let png = ReceiptExportView.renderPNG(of: receipt) {
            return .result(value: IntentFile(data: png, filename: "\(fileName).png", type: .png))
        }
        let pdf = ReceiptPDFRenderer(receipt: receipt).render()
        return .result(value: IntentFile(data: pdf, filename: "\(fileName).pdf", type: .pdf))
    }
}
