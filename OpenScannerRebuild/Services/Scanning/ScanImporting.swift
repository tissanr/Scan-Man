import Foundation
import UIKit

protocol ScanImporting {
    func makeScanDocument(from images: [UIImage], createdAt: Date) throws -> ScanDocument
}

enum ScanImportError: LocalizedError {
    case noPages
    case imageEncodingFailed(pageIndex: Int)

    var errorDescription: String? {
        switch self {
        case .noPages:
            return "The scan did not contain any pages."
        case .imageEncodingFailed(let pageIndex):
            return "Open Scanner could not save page \(pageIndex + 1)."
        }
    }
}
