import Foundation
import UIKit
@testable import OpenScannerRebuild

/// In-memory repository that records calls.
final class StubScanRepository: ScanRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var scansByID: [UUID: ScanDocument] = [:]
    private var _saveCalls: [ScanDocument] = []
    private var _ocrApplications: [(UUID, [PageOCRResult])] = []

    init(scans: [ScanDocument] = []) {
        scans.forEach { scansByID[$0.id] = $0 }
    }

    var saveCalls: [ScanDocument] { lock.withLock { _saveCalls } }
    var ocrApplicationCount: Int { lock.withLock { _ocrApplications.count } }
    var storedScans: [ScanDocument] { lock.withLock { Array(scansByID.values) } }

    func fetchSummaries() async throws -> [ScanSummary] {
        lock.withLock {
            scansByID.values.sorted { $0.updatedAt > $1.updatedAt }.map(ScanSummary.init(scan:))
        }
    }

    func fetchScan(id: UUID) async throws -> ScanDocument? {
        lock.withLock { scansByID[id] }
    }

    func save(scan: ScanDocument) async throws {
        lock.withLock {
            _saveCalls.append(scan)
            scansByID[scan.id] = scan
        }
    }

    func updateTitle(scanID: UUID, title: String) async throws {
        try mutate(scanID) { $0.title = title }
    }

    func updateNotes(scanID: UUID, notes: String) async throws {
        try mutate(scanID) { $0.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    func updateRecognizedText(scanID: UUID, pageID: UUID, text: String) async throws {
        try mutate(scanID) { scan in
            guard let index = scan.pages.firstIndex(where: { $0.id == pageID }) else { throw AppError.notFound }
            scan.pages[index].recognizedText = text.normalizedOCRText
        }
    }

    func applyOCRResults(scanID: UUID, results: [PageOCRResult], suggestedTitle: String?) async throws {
        lock.withLock { _ocrApplications.append((scanID, results)) }
        guard lock.withLock({ scansByID[scanID] }) != nil else { return }
        try mutate(scanID) { scan in
            for result in results {
                guard let index = scan.pages.firstIndex(where: { $0.id == result.pageID }) else { continue }
                scan.pages[index].textObservations = result.observations
                if scan.pages[index].recognizedText.isEmpty {
                    scan.pages[index].recognizedText = result.text
                }
            }
            if let suggestedTitle, ScanDefaults.isPlaceholderTitle(scan.title, createdAt: scan.createdAt) {
                scan.title = suggestedTitle
            }
        }
    }

    func appendPages(scanID: UUID, pages: [ScanPage]) async throws {
        try mutate(scanID) { scan in
            var next = scan.pages.count
            for var page in pages {
                page.order = next
                next += 1
                scan.pages.append(page)
            }
        }
    }

    func deletePage(scanID: UUID, pageID: UUID) async throws {
        try mutate(scanID) { scan in
            guard scan.pages.count > 1 else { throw AppError.lastPageCannotBeDeleted }
            scan.pages.removeAll { $0.id == pageID }
            for index in scan.pages.indices { scan.pages[index].order = index }
        }
    }

    func reorderPages(scanID: UUID, orderedPageIDs: [UUID]) async throws {
        try mutate(scanID) { scan in
            scan.pages = orderedPageIDs.compactMap { id in scan.pages.first { $0.id == id } }
            for index in scan.pages.indices { scan.pages[index].order = index }
        }
    }

    func replacePageImage(scanID: UUID, pageID: UUID, update: PageImageUpdate) async throws {
        try mutate(scanID) { scan in
            guard let index = scan.pages.firstIndex(where: { $0.id == pageID }) else { throw AppError.notFound }
            scan.pages[index].imageData = update.imageData
            scan.pages[index].processedImageData = update.processedImageData
            scan.pages[index].enhancement = update.enhancement
            scan.pages[index].thumbnailData = update.thumbnailData
            if update.resetsOCR {
                scan.pages[index].recognizedText = ""
                scan.pages[index].textObservations = []
            }
        }
    }

    func delete(scanID: UUID) async throws {
        _ = lock.withLock { scansByID.removeValue(forKey: scanID) }
    }

    func deleteAll() async throws {
        lock.withLock { scansByID.removeAll() }
    }

    func rebuildDerivedFieldsIfNeeded() async throws -> Int { 0 }

    private func mutate(_ scanID: UUID, _ change: (inout ScanDocument) throws -> Void) throws {
        try lock.withLock {
            guard var scan = scansByID[scanID] else { throw AppError.notFound }
            try change(&scan)
            scan.updatedAt = Date()
            scansByID[scanID] = scan
        }
    }
}

struct StubDeviceSupport: ScanDeviceSupporting {
    var canScanDocuments: Bool
    var cameraAccess: CameraAccess = .authorized
    var unavailableMessage: String { "Unavailable" }
}

/// Builds pages without image processing and records its inputs.
final class StubScanImporter: ScanImporting, @unchecked Sendable {
    private let lock = NSLock()
    private var _imagesInput: [[Data]] = []
    private var _pdfInput: [Data] = []

    var imagesInput: [[Data]] { lock.withLock { _imagesInput } }
    var pdfInput: [Data] { lock.withLock { _pdfInput } }

    func makeScanDocument(fromImageData imageData: [Data], createdAt: Date, options: ImportOptions) async throws -> ScanDocument {
        lock.withLock { _imagesInput.append(imageData) }
        return Self.document(pages: Self.pages(count: imageData.count, startingOrder: 0), createdAt: createdAt)
    }

    func makeScanDocument(fromPDFData pdfData: Data, createdAt: Date, options: ImportOptions) async throws -> ScanDocument {
        lock.withLock { _pdfInput.append(pdfData) }
        return Self.document(pages: Self.pages(count: 1, startingOrder: 0), createdAt: createdAt)
    }

    func makePages(fromImageData imageData: [Data], startingOrder: Int, createdAt: Date, options: ImportOptions) async throws -> [ScanPage] {
        lock.withLock { _imagesInput.append(imageData) }
        return Self.pages(count: imageData.count, startingOrder: startingOrder)
    }

    private static func pages(count: Int, startingOrder: Int) -> [ScanPage] {
        (0..<count).map { index in
            ScanPage(id: UUID(), order: startingOrder + index, createdAt: Date(), imageData: Data([0xFF, 0xD8, UInt8(index)]),
                     thumbnailData: Data(), recognizedText: "", textObservations: [])
        }
    }

    private static func document(pages: [ScanPage], createdAt: Date) -> ScanDocument {
        ScanDocument(id: UUID(), createdAt: createdAt, updatedAt: createdAt,
                     title: ScanDefaults.defaultTitle(for: createdAt), notes: "", pages: pages)
    }
}

final class StubImportInbox: ImportInboxManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var _pending: [PendingImportItem]
    private var _removed: [PendingImportItem] = []

    init(mockPendingImports: [PendingImportItem] = []) {
        _pending = mockPendingImports
    }

    var importFolderDisplayPath: String { "Files > On My iPhone > Scan Man > Scan Man Imports" }
    var removedItems: [PendingImportItem] { lock.withLock { _removed } }

    func prepareImportLocations() throws {}

    func pendingImports() throws -> [PendingImportItem] {
        lock.withLock { _pending }
    }

    func removeImportedItem(_ item: PendingImportItem) throws {
        lock.withLock {
            _removed.append(item)
            _pending.removeAll { $0 == item }
        }
    }
}

struct StubOCRRecognizer: OCRRecognizing {
    let contentByPayload: [Data: OCRPageContent]
    var failingPayloads: Set<Data> = []

    func recognizePage(in imageData: Data) async throws -> OCRPageContent {
        if failingPayloads.contains(imageData) {
            throw AppError.ocr("stub failure")
        }
        return contentByPayload[imageData] ?? OCRPageContent(text: "", observations: [])
    }
}

/// Returns a fixed text for every page (or nothing).
struct StubOCRProcessor: ScanOCRProcessing {
    var text = ""
    var suggestedTitle: String?

    func process(pages: [ScanPage], suggestTitle: Bool) async -> ScanOCRProcessingResult {
        ScanOCRProcessingResult(
            pageResults: pages.map { PageOCRResult(pageID: $0.id, text: text, observations: []) },
            failedPageIDs: [],
            suggestedTitle: suggestTitle ? suggestedTitle : nil
        )
    }
}

/// Wires view models to doubles.
@MainActor
struct TestEnvironment {
    let repository: ScanRepository
    let importer: ScanImporting
    let inbox: ImportInboxManaging
    let settings = AppSettings(defaults: TestData.isolatedDefaults())
    let events = LibraryEvents()
    let ocrCoordinator: OCRCoordinator
    var deviceSupport = StubDeviceSupport(canScanDocuments: true)

    init(
        repository: ScanRepository = StubScanRepository(),
        importer: ScanImporting = StubScanImporter(),
        inbox: ImportInboxManaging = StubImportInbox(),
        ocrProcessor: ScanOCRProcessing = StubOCRProcessor()
    ) {
        self.repository = repository
        self.importer = importer
        self.inbox = inbox
        self.ocrCoordinator = OCRCoordinator(repository: repository, processor: ocrProcessor, events: events)
    }

    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(repository: repository, ocrCoordinator: ocrCoordinator, scanDeviceSupport: deviceSupport,
                      scanImporter: importer, importInbox: inbox, settings: settings, events: events)
    }

    func makeDetailViewModel(scanID: UUID) -> ScanDetailViewModel {
        let imageProcessor = CoreImageProcessor()
        return ScanDetailViewModel(scanID: scanID, repository: repository, pdfExporter: PDFExportService(imageProcessor: imageProcessor),
                                   imageProcessor: imageProcessor, scanImporter: importer, ocrCoordinator: ocrCoordinator,
                                   scanDeviceSupport: deviceSupport, settings: settings, events: events)
    }
}

/// Waits until `condition` holds, yielding so background tasks can run.
@MainActor
func waitUntil(timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition() {
        if clock.now > deadline { return false }
        try? await Task.sleep(for: .milliseconds(20))
    }
    return true
}
