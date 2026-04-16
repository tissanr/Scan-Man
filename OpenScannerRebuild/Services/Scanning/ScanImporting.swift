import Foundation
import UIKit

protocol ScanImporting {
    func makeScanDocument(from images: [UIImage], createdAt: Date) throws -> ScanDocument
    func makeScanDocument(fromPDFData pdfData: Data, createdAt: Date) throws -> ScanDocument
}

enum ScanImportError: LocalizedError {
    case noPages
    case imageEncodingFailed(pageIndex: Int)
    case invalidPDF
    case pdfPageRenderingFailed(pageIndex: Int)

    var errorDescription: String? {
        switch self {
        case .noPages:
            return "The scan did not contain any pages."
        case .imageEncodingFailed(let pageIndex):
            return "Open Scanner could not save page \(pageIndex + 1)."
        case .invalidPDF:
            return "Open Scanner could not read that PDF."
        case .pdfPageRenderingFailed(let pageIndex):
            return "Open Scanner could not import PDF page \(pageIndex + 1)."
        }
    }
}
