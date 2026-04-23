import Foundation
import Combine
import UIKit

@MainActor
final class HomeViewModel: ObservableObject {
    private let repository: ScanRepository
    private let titleSuggester: TitleSuggesting
    private let ocrProcessor: ScanOCRProcessing
    private let scanDeviceSupport: ScanDeviceSupporting
    private let scanImporter: ScanImporting
    private let importInbox: ImportInboxManaging

    @Published private(set) var scans: [ScanDocument] = []
    @Published var searchText = ""
    @Published private(set) var activeErrorMessage: String?
    @Published private(set) var isShowingScanner = false
    @Published private(set) var isImporting = false
    @Published private(set) var pendingNavigationScan: ScanDocument?

    init(repository: ScanRepository, titleSuggester: TitleSuggesting, ocrProcessor: ScanOCRProcessing, scanDeviceSupport: ScanDeviceSupporting, scanImporter: ScanImporting, importInbox: ImportInboxManaging) {
        self.repository = repository
        self.titleSuggester = titleSuggester
        self.ocrProcessor = ocrProcessor
        self.scanDeviceSupport = scanDeviceSupport
        self.scanImporter = scanImporter
        self.importInbox = importInbox
    }

    var filteredScans: [ScanDocument] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return scans
        }

        let normalizedQuery = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return scans.filter { $0.searchText.contains(normalizedQuery) }
    }

    var scanButtonAccessibilityLabel: String {
        "Scan document"
    }

    var scanSupportMessage: String? {
        guard !scanDeviceSupport.canScanDocuments else {
            return nil
        }

        return scanDeviceSupport.unavailableMessage
    }

    var importFolderDisplayPath: String {
        importInbox.importFolderDisplayPath
    }

    func load() async {
        do {
            try importInbox.prepareImportLocations()
            await AppSeeder.seedIfNeeded(using: repository)
            scans = try await repository.fetchScans()
            await importPendingInboxItems()
        } catch {
            activeErrorMessage = "Unable to load scans right now."
        }
    }

    func refreshImportSources() async {
        do {
            try importInbox.prepareImportLocations()
            await importPendingInboxItems()
        } catch {
            activeErrorMessage = "Unable to read the Scan Man import folder right now."
        }
    }

    func delete(_ scan: ScanDocument) async {
        do {
            try await repository.delete(scanID: scan.id)
            scans.removeAll { $0.id == scan.id }
        } catch {
            activeErrorMessage = "Unable to delete that scan."
        }
    }

    func beginScan() {
        guard scanDeviceSupport.canScanDocuments else {
            activeErrorMessage = scanDeviceSupport.unavailableMessage
            return
        }

        isShowingScanner = true
    }

    func handleScanCancel() {
        isShowingScanner = false
    }

    func handleScanFailure(_ error: Error) {
        isShowingScanner = false
        activeErrorMessage = error.localizedDescription.isEmpty ? "Scanning failed. Please try again." : error.localizedDescription
    }

    func handleScan(images: [UIImage]) async {
        isShowingScanner = false
        await importScanDocument(from: .images(images))
    }

    func handleImportedImages(_ images: [UIImage]) async {
        await importScanDocument(from: .images(images))
    }

    func handleImportedPDF(_ pdfData: Data) async {
        await importScanDocument(from: .pdf(pdfData))
    }

    func importPhotos(from itemData: [Data]) async {
        let images = itemData.compactMap(UIImage.init(data:))
        guard !images.isEmpty else {
            activeErrorMessage = "Open Scanner could not import those photos."
            return
        }

        await handleImportedImages(images)
    }

    func dismissError() {
        activeErrorMessage = nil
    }

    func consumePendingNavigation() -> ScanDocument? {
        let value = pendingNavigationScan
        pendingNavigationScan = nil
        return value
    }

    func suggestedTitle(for pages: [ScanPage]) -> String {
        titleSuggester.suggestTitle(for: pages)
    }

    private func processOCR(for scan: ScanDocument) async {
        let result = await ocrProcessor.process(scan: scan)

        do {
            try await repository.save(scan: result.scan)
            if let index = scans.firstIndex(where: { $0.id == result.scan.id }) {
                scans[index] = result.scan
            } else {
                await load()
            }

            if result.failedPageCount == result.scan.pages.count, !result.scan.pages.isEmpty {
                activeErrorMessage = "OCR could not read this scan, but the pages were saved successfully."
            }
        } catch {
            activeErrorMessage = "The scan was saved, but OCR results could not be stored."
        }
    }

    private func importScanDocument(from source: ImportSource) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let createdAt = Date()
            let scan: ScanDocument
            switch source {
            case .images(let images):
                scan = try scanImporter.makeScanDocument(from: images, createdAt: createdAt)
            case .pdf(let data):
                scan = try scanImporter.makeScanDocument(fromPDFData: data, createdAt: createdAt)
            }

            try await repository.save(scan: scan)
            scans.insert(scan, at: 0)
            pendingNavigationScan = scan
            Task {
                await processOCR(for: scan)
            }
        } catch {
            activeErrorMessage = error.localizedDescription.isEmpty ? "Open Scanner could not import that document." : error.localizedDescription
        }
    }

    private func importPendingInboxItems() async {
        let items: [PendingImportItem]
        do {
            items = try importInbox.pendingImports()
        } catch {
            activeErrorMessage = "Unable to read pending imports."
            return
        }

        guard !items.isEmpty else {
            return
        }

        for item in items {
            do {
                let data = try Data(contentsOf: item.url)
                let createdAt = Date()
                let scan: ScanDocument

                switch item.kind {
                case .image:
                    guard let image = UIImage(data: data) else {
                        throw ScanImportError.imageEncodingFailed(pageIndex: 0)
                    }
                    scan = try scanImporter.makeScanDocument(from: [image], createdAt: createdAt)
                case .pdf:
                    scan = try scanImporter.makeScanDocument(fromPDFData: data, createdAt: createdAt)
                }

                try await repository.save(scan: scan)
                scans.insert(scan, at: 0)
                try importInbox.removeImportedItem(item)

                Task {
                    await processOCR(for: scan)
                }
            } catch {
                activeErrorMessage = "Open Scanner could not import one of the files from the Scan Man import folder."
            }
        }
    }
}

private extension HomeViewModel {
    enum ImportSource {
        case images([UIImage])
        case pdf(Data)
    }
}
