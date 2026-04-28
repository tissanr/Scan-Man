import Foundation
import UIKit
@testable import OpenScannerRebuild

final class StubScanRepository: ScanRepository {
    private(set) var storedScans: [ScanDocument]
    private(set) var saveCalls: [ScanDocument] = []

    init(scans: [ScanDocument] = []) {
        self.storedScans = scans
    }

    func fetchScans() async throws -> [ScanDocument] {
        storedScans
    }

    func fetchScan(id: UUID) async throws -> ScanDocument? {
        storedScans.first(where: { $0.id == id })
    }

    func save(scan: ScanDocument) async throws {
        saveCalls.append(scan)
        if let index = storedScans.firstIndex(where: { $0.id == scan.id }) {
            storedScans[index] = scan
        } else {
            storedScans.append(scan)
        }
    }

    func updateTitle(scanID: UUID, title: String) async throws {
    }

    func updateNotes(scanID: UUID, notes: String) async throws {
        guard let scanIndex = storedScans.firstIndex(where: { $0.id == scanID }) else {
            return
        }

        storedScans[scanIndex].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateRecognizedText(scanID: UUID, pageID: UUID, text: String) async throws {
        guard let scanIndex = storedScans.firstIndex(where: { $0.id == scanID }),
              let pageIndex = storedScans[scanIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }

        storedScans[scanIndex].pages[pageIndex].recognizedText = text.normalizedOCRText
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

final class StubScanImporter: ScanImporting {
    var imagesInput: [[UIImage]] = []
    var pdfInput: [Data] = []
    
    func makeScanDocument(from images: [UIImage], createdAt: Date) throws -> ScanDocument {
        imagesInput.append(images)
        let pages = images.enumerated().map { index, _ in
            TestData.page(order: index, text: "Imported Page \(index + 1)")
        }
        return TestData.scan(title: "Imported \(images.count) Images", pages: pages)
    }

    func makeScanDocument(fromPDFData pdfData: Data, createdAt: Date) throws -> ScanDocument {
        pdfInput.append(pdfData)
        return TestData.scan(title: "Imported PDF", pages: [TestData.page(order: 0, text: "Imported PDF Content")])
    }
}

struct StubImportInbox: ImportInboxManaging {
    var importFolderDisplayPath: String { "Files > On My iPhone > Scan Man > Scan Man Imports" }
    var mockPendingImports: [PendingImportItem] = []

    func prepareImportLocations() throws {
    }

    func pendingImports() throws -> [PendingImportItem] {
        mockPendingImports
    }

    func removeImportedItem(_ item: PendingImportItem) throws {
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
