import SwiftUI

/// Renders the receipt image only when the share sheet asks for it, not on every update.
struct ReceiptImageExport: Transferable {
    let name: String
    let render: @MainActor () -> Data?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            guard let data = await export.render() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
        .suggestedFileName { $0.name }
    }
}
