import Foundation
import PDFKit
import SwiftUI

// Adapted from:
// https://developer.apple.com/forums/thread/708538
// Thanks to tomas.bek
extension PDFDocument: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .pdf) { pdf in
            if let data = pdf.dataRepresentation() {
                return data
            } else {
                return Data()
            }
        } importing: { data in
            if let pdf = PDFDocument(data: data) {
                return pdf
            } else {
                return PDFDocument()
            }
        }
        .suggestedFileName { pdf in
            return pdf.documentAttributes?["Title"] as? String
        }
        DataRepresentation(exportedContentType: .pdf) { pdf in
            if let data = pdf.dataRepresentation() {
                return data
            } else {
                return Data()
            }
        }
     }
}
