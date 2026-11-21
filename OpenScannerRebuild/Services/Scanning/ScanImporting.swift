import Foundation

/// Turns captured or imported images and PDFs into scan pages.
nonisolated protocol ScanImporting: Sendable {
    /// A new scan with one page per image. `imageData` may be any encoded image format.
    func makeScanDocument(fromImageData imageData: [Data], createdAt: Date, options: ImportOptions) async throws -> ScanDocument

    /// A new scan with one page per PDF page.
    func makeScanDocument(fromPDFData pdfData: Data, createdAt: Date, options: ImportOptions) async throws -> ScanDocument

    /// Pages for appending to an existing scan, numbered from `startingOrder`.
    func makePages(fromImageData imageData: [Data], startingOrder: Int, createdAt: Date, options: ImportOptions) async throws -> [ScanPage]
}

nonisolated enum ScanImportError: LocalizedError, Equatable, Sendable {
    case noPages
    case unreadableImage(pageIndex: Int)
    case invalidPDF
    case pdfPageRenderingFailed(pageIndex: Int)

    var errorDescription: String? {
        switch self {
        case .noPages:
            "The document did not contain any pages."
        case .unreadableImage(let pageIndex):
            "Scan Man could not read image \(pageIndex + 1)."
        case .invalidPDF:
            "Scan Man could not read that PDF. It may be damaged or password-protected."
        case .pdfPageRenderingFailed(let pageIndex):
            "Scan Man could not import PDF page \(pageIndex + 1)."
        }
    }
}
