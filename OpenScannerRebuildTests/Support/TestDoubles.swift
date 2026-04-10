import Foundation
import UIKit
@testable import OpenScannerRebuild

final class StubScanRepository: ScanRepository {
    private let storedScans: [ScanDocument]

    init(scans: [ScanDocument]) {
        self.storedScans = scans
    }

    func fetchScans() async throws -> [ScanDocument] {
        storedScans
    }

    func fetchScan(id: UUID) async throws -> ScanDocument? {
        storedScans.first(where: { $0.id == id })
    }

    func save(scan: ScanDocument) async throws {
    }

    func updateTitle(scanID: UUID, title: String) async throws {
    }

    func delete(scanID: UUID) async throws {
    }

    func deleteAll() async throws {
    }
}

struct StubDeviceSupport: ScanDeviceSupporting {
    let canScanDocuments: Bool
    var unavailableMessage: String { "Unavailable" }
}

struct StubScanImporter: ScanImporting {
    var result: Result<ScanDocument, Error>

    func makeScanDocument(from images: [UIImage], createdAt: Date) throws -> ScanDocument {
        try result.get()
    }
}

struct StubOCRRecognizer: OCRRecognizing {
    let contentByPayload: [Data: OCRPageContent]
    let failingPayloads: Set<Data>

    func recognizePage(in imageData: Data) async throws -> OCRPageContent {
        if failingPayloads.contains(imageData) {
            throw OCRServiceError.invalidImageData
        }

        return contentByPayload[imageData] ?? OCRPageContent(text: "", observations: [])
    }
}

struct StubOCRProcessor: ScanOCRProcessing {
    let result: ScanOCRProcessingResult

    func process(scan: ScanDocument) async -> ScanOCRProcessingResult {
        result
    }
}
