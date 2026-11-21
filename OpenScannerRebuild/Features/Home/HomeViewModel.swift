import Foundation
import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class HomeViewModel {
    @ObservationIgnored private let repository: ScanRepository
    @ObservationIgnored private let ocrCoordinator: OCRCoordinator
    @ObservationIgnored private let scanDeviceSupport: ScanDeviceSupporting
    @ObservationIgnored private let scanImporter: ScanImporting
    @ObservationIgnored private let importInbox: ImportInboxManaging
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let events: LibraryEvents
    @ObservationIgnored private var isImportingInbox = false

    private(set) var scans: [ScanSummary] = []
    var searchText = ""
    private(set) var activeErrorMessage: String?
    /// The current error can be fixed in the Settings app (e.g. camera access).
    private(set) var errorOffersSettingsLink = false
    private(set) var isShowingScanner = false
    private(set) var isImporting = false
    private(set) var pendingNavigationScanID: UUID?

    init(
        repository: ScanRepository,
        ocrCoordinator: OCRCoordinator,
        scanDeviceSupport: ScanDeviceSupporting,
        scanImporter: ScanImporting,
        importInbox: ImportInboxManaging,
        settings: AppSettings,
        events: LibraryEvents
    ) {
        self.repository = repository
        self.ocrCoordinator = ocrCoordinator
        self.scanDeviceSupport = scanDeviceSupport
        self.scanImporter = scanImporter
        self.importInbox = importInbox
        self.settings = settings
        self.events = events
    }

    var filteredScans: [ScanSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return scans
        }
        return scans.filter { $0.matches(query) }
    }

    var scanButtonAccessibilityLabel: String {
        "Scan document"
    }

    var scanSupportMessage: String? {
        scanDeviceSupport.canScanDocuments ? nil : scanDeviceSupport.unavailableMessage
    }

    var importFolderDisplayPath: String {
        importInbox.importFolderDisplayPath
    }

    func isRecognizingText(scanID: UUID) -> Bool {
        ocrCoordinator.isRecognizing(scanID: scanID)
    }

    // MARK: - Loading

    func load() async {
        do {
            try importInbox.prepareImportLocations()
        } catch {
            Logger.importing.error("Could not create import folders: \(error.localizedDescription, privacy: .public)")
        }
        await reload()
        await importPendingInboxItems()
    }

    /// Re-reads the library; called whenever ``LibraryEvents`` reports a change.
    func reload() async {
        do {
            scans = try await repository.fetchSummaries()
        } catch {
            present(error, fallback: AppError.persistence)
        }
    }

    func refreshImportSources() async {
        await importPendingInboxItems()
    }

    func delete(_ scan: ScanSummary) async {
        do {
            try await repository.delete(scanID: scan.id)
            scans.removeAll { $0.id == scan.id }
            events.libraryDidChange()
        } catch {
            present(error, fallback: AppError.persistence)
        }
    }

    // MARK: - Capture

    func beginScan() {
        guard scanDeviceSupport.canScanDocuments else {
            present(message: scanDeviceSupport.unavailableMessage)
            return
        }
        guard scanDeviceSupport.cameraAccess != .denied else {
            present(AppError.cameraAccessDenied)
            return
        }
        isShowingScanner = true
    }

    func handleScanCancel() {
        isShowingScanner = false
    }

    func handleScanFailure(_ error: Error) {
        isShowingScanner = false
        present(error, fallback: AppError.scanCapture)
    }

    func handleScan(images: [UIImage]) async {
        isShowingScanner = false
        await importImages(images.compactMap { $0.jpegData(compressionQuality: 0.95) })
    }

    func importPhotos(from itemData: [Data]) async {
        guard !itemData.isEmpty else {
            present(AppError.importFailed("Scan Man could not load those photos."))
            return
        }
        await importImages(itemData)
    }

    func handleImportedPDF(_ pdfData: Data) async {
        await importNewScan { [scanImporter, settings] createdAt in
            try await scanImporter.makeScanDocument(fromPDFData: pdfData, createdAt: createdAt, options: settings.importOptions)
        }
    }

    func dismissError() {
        activeErrorMessage = nil
        errorOffersSettingsLink = false
    }

    func consumePendingNavigation() -> UUID? {
        let value = pendingNavigationScanID
        pendingNavigationScanID = nil
        return value
    }

    // MARK: - Import

    private func importImages(_ imageData: [Data]) async {
        await importNewScan { [scanImporter, settings] createdAt in
            try await scanImporter.makeScanDocument(fromImageData: imageData, createdAt: createdAt, options: settings.importOptions)
        }
    }

    /// Builds a scan, stores it, opens it, and starts OCR in the background.
    private func importNewScan(_ make: (Date) async throws -> ScanDocument) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let scan = try await make(Date())
            try await repository.save(scan: scan)
            scans.insert(ScanSummary(scan: scan), at: 0)
            pendingNavigationScanID = scan.id
            events.libraryDidChange()
            startOCR(for: scan)
        } catch {
            present(error, fallback: AppError.importFailed)
        }
    }

    private func startOCR(for scan: ScanDocument) {
        Task {
            let outcome = await ocrCoordinator.recognize(scanID: scan.id, pages: scan.pages, suggestTitle: true)
            switch outcome {
            case .completed:
                break
            case .allPagesFailed:
                present(message: "Scan Man could not read text in this scan, but the pages were saved.")
            case .saveFailed:
                present(message: "The scan was saved, but its text could not be stored.")
            }
        }
    }

    private func importPendingInboxItems() async {
        guard !isImportingInbox else { return }
        isImportingInbox = true
        defer { isImportingInbox = false }

        let items: [PendingImportItem]
        do {
            items = try importInbox.pendingImports()
        } catch {
            Logger.importing.error("Could not read import folders: \(error.localizedDescription, privacy: .public)")
            present(message: "Scan Man could not read the import folder.")
            return
        }

        guard !items.isEmpty else {
            return
        }

        // PDFs are always separate scans. Images are grouped per source into one multi-page scan.
        for item in items where item.kind == .pdf {
            await importSingleFileItem(item)
        }

        let imageItemsBySource = Dictionary(grouping: items.filter { $0.kind == .image }, by: \.source)
        for source in [PendingImportItem.Source.shareExtension, .visibleFolder] {
            if let sourceItems = imageItemsBySource[source] {
                await importGroupedImageItems(sourceItems)
            }
        }
    }

    private func importSingleFileItem(_ item: PendingImportItem) async {
        do {
            let data = try Data(contentsOf: item.url)
            let scan = try await scanImporter.makeScanDocument(fromPDFData: data, createdAt: Date(), options: settings.importOptions)
            try await repository.save(scan: scan)
            scans.insert(ScanSummary(scan: scan), at: 0)
            try importInbox.removeImportedItem(item)
            events.libraryDidChange()
            startOCR(for: scan)
        } catch {
            Logger.importing.error("Inbox PDF import failed: \(error.localizedDescription, privacy: .public)")
            present(message: "Scan Man could not import \(item.url.lastPathComponent).")
        }
    }

    private func importGroupedImageItems(_ items: [PendingImportItem]) async {
        var imageData: [Data] = []
        var importedItems: [PendingImportItem] = []
        for item in items {
            // Only keep files that decode, so one bad file doesn't block the rest.
            if let data = try? Data(contentsOf: item.url), UIImage(data: data) != nil {
                imageData.append(data)
                importedItems.append(item)
            } else {
                Logger.importing.error("Skipping unreadable inbox image \(item.url.lastPathComponent, privacy: .private)")
            }
        }

        guard !imageData.isEmpty else { return }

        do {
            let scan = try await scanImporter.makeScanDocument(fromImageData: imageData, createdAt: Date(), options: settings.importOptions)
            try await repository.save(scan: scan)
            scans.insert(ScanSummary(scan: scan), at: 0)
            // Only consume files that made it into the scan; unreadable ones stay in the inbox.
            for item in importedItems {
                try? importInbox.removeImportedItem(item)
            }
            events.libraryDidChange()
            startOCR(for: scan)
        } catch {
            Logger.importing.error("Inbox image import failed: \(error.localizedDescription, privacy: .public)")
            present(message: "Scan Man could not import images from the import folder.")
        }
    }

    // MARK: - Errors

    private func present(_ error: Error, fallback: (String) -> AppError) {
        present(AppError.wrap(error, as: fallback))
    }

    private func present(_ error: AppError) {
        Logger.ui.error("Home error: \(error.debugDetail, privacy: .public)")
        activeErrorMessage = error.localizedDescription
        errorOffersSettingsLink = error == .cameraAccessDenied
    }

    private func present(message: String) {
        activeErrorMessage = message
        errorOffersSettingsLink = false
    }
}
