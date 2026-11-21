import Foundation
import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class ScanDetailViewModel {
    let scanID: UUID

    @ObservationIgnored private let repository: ScanRepository
    @ObservationIgnored private let pdfExporter: PDFExporting
    @ObservationIgnored private let imageProcessor: ImageProcessing
    @ObservationIgnored private let scanImporter: ScanImporting
    @ObservationIgnored private let ocrCoordinator: OCRCoordinator
    @ObservationIgnored private let scanDeviceSupport: ScanDeviceSupporting
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let events: LibraryEvents

    private(set) var scan: ScanDocument?
    private(set) var isLoaded = false
    private(set) var isWorking = false
    private(set) var activeErrorMessage: String?
    private(set) var exportedFile: ExportedFile?
    private(set) var isShowingScanner = false
    var titleDraft = ""
    var notesDraft = ""

    init(
        scanID: UUID,
        repository: ScanRepository,
        pdfExporter: PDFExporting,
        imageProcessor: ImageProcessing,
        scanImporter: ScanImporting,
        ocrCoordinator: OCRCoordinator,
        scanDeviceSupport: ScanDeviceSupporting,
        settings: AppSettings,
        events: LibraryEvents
    ) {
        self.scanID = scanID
        self.repository = repository
        self.pdfExporter = pdfExporter
        self.imageProcessor = imageProcessor
        self.scanImporter = scanImporter
        self.ocrCoordinator = ocrCoordinator
        self.scanDeviceSupport = scanDeviceSupport
        self.settings = settings
        self.events = events
    }

    var title: String {
        scan?.title ?? ""
    }

    var pages: [ScanPage] {
        scan?.orderedPages ?? []
    }

    var notes: String {
        scan?.notes ?? ""
    }

    var isRecognizingText: Bool {
        ocrCoordinator.isRecognizing(scanID: scanID)
    }

    var canScanMorePages: Bool {
        scanDeviceSupport.canScanDocuments
    }

    var canDeletePages: Bool {
        pages.count > 1
    }

    func page(for pageID: UUID) -> ScanPage? {
        scan?.pages.first { $0.id == pageID }
    }

    // MARK: - Loading

    /// Loads (or reloads) the scan. Drafts the user hasn't changed follow the stored values.
    func load() async {
        do {
            let previous = scan
            guard let loaded = try await repository.fetchScan(id: scanID) else {
                scan = nil
                isLoaded = true
                return
            }
            scan = loaded
            if previous == nil || titleDraft == previous?.title {
                titleDraft = loaded.title
            }
            if previous == nil || notesDraft == previous?.notes {
                notesDraft = loaded.notes
            }
            isLoaded = true
        } catch {
            present(error, fallback: AppError.persistence)
        }
    }

    // MARK: - Title and notes

    func saveTitle() async {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scan, trimmed != scan.title else { return }
        await perform {
            try await self.repository.updateTitle(scanID: self.scanID, title: trimmed)
        }
        titleDraft = self.scan?.title ?? trimmed
    }

    var hasUnsavedNotes: Bool {
        notesDraft.trimmingCharacters(in: .whitespacesAndNewlines) != notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    func saveNotes() async -> Bool {
        let draft = notesDraft
        let saved = await perform {
            try await self.repository.updateNotes(scanID: self.scanID, notes: draft)
        }
        if saved {
            notesDraft = notes
        }
        return saved
    }

    // MARK: - Page text

    @discardableResult
    func updateRecognizedText(for pageID: UUID, text: String) async -> Bool {
        await perform {
            try await self.repository.updateRecognizedText(scanID: self.scanID, pageID: pageID, text: text)
        }
    }

    // MARK: - Page management

    func deletePage(_ pageID: UUID) async {
        guard canDeletePages else {
            present(AppError.lastPageCannotBeDeleted)
            return
        }
        await perform {
            try await self.repository.deletePage(scanID: self.scanID, pageID: pageID)
        }
    }

    func deletePages(at offsets: IndexSet) async {
        let ids = offsets.map { pages[$0].id }
        guard ids.count < pages.count else {
            present(AppError.lastPageCannotBeDeleted)
            return
        }
        for id in ids {
            await deletePage(id)
        }
    }

    func movePages(from source: IndexSet, to destination: Int) async {
        var ids = pages.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        await perform {
            try await self.repository.reorderPages(scanID: self.scanID, orderedPageIDs: ids)
        }
    }

    /// Rotates a page by 90°, then re-runs OCR because the text geometry changed.
    func rotatePage(_ pageID: UUID, clockwise: Bool) async {
        await replaceImage(of: pageID, resetsOCR: true) { [imageProcessor] page in
            try await imageProcessor.rotated(page.imageData, quarterTurns: clockwise ? 1 : -1)
        }
    }

    func cropPage(_ pageID: UUID, to quad: DocumentQuad) async {
        await replaceImage(of: pageID, resetsOCR: true) { [imageProcessor] page in
            try await imageProcessor.cropped(page.imageData, to: quad)
        }
    }

    /// Changes the visual filter. OCR is not repeated: it always runs on the unfiltered original.
    func setEnhancement(_ enhancement: ImageEnhancement, for pageID: UUID) async {
        guard let page = page(for: pageID), page.enhancement != enhancement else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let processed = try await imageProcessor.applying(enhancement, to: page.imageData)
            let thumbnail = try await imageProcessor.thumbnail(from: processed ?? page.imageData)
            let update = PageImageUpdate(imageData: page.imageData, processedImageData: processed,
                                         enhancement: enhancement, thumbnailData: thumbnail, resetsOCR: false)
            try await repository.replacePageImage(scanID: scanID, pageID: pageID, update: update)
            await didChange()
        } catch {
            present(error, fallback: AppError.imageProcessing)
        }
    }

    func detectDocument(in pageID: UUID) async -> DocumentQuad? {
        guard let page = page(for: pageID) else { return nil }
        return await imageProcessor.detectDocument(in: page.imageData)
    }

    // MARK: - Adding pages

    func beginScanningPages() {
        guard scanDeviceSupport.canScanDocuments else {
            present(AppError.scanCapture(scanDeviceSupport.unavailableMessage))
            return
        }
        guard scanDeviceSupport.cameraAccess != .denied else {
            present(AppError.cameraAccessDenied)
            return
        }
        isShowingScanner = true
    }

    func cancelScanningPages() {
        isShowingScanner = false
    }

    func handleScanFailure(_ error: Error) {
        isShowingScanner = false
        present(error, fallback: AppError.scanCapture)
    }

    func appendScannedImages(_ images: [UIImage]) async {
        isShowingScanner = false
        await appendPages(fromImageData: images.compactMap { $0.jpegData(compressionQuality: 0.95) })
    }

    func appendPages(fromImageData imageData: [Data]) async {
        guard !imageData.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let newPages = try await scanImporter.makePages(
                fromImageData: imageData,
                startingOrder: pages.count,
                createdAt: Date(),
                options: settings.importOptions
            )
            try await repository.appendPages(scanID: scanID, pages: newPages)
            await didChange()
            startOCR(for: newPages)
        } catch {
            present(error, fallback: AppError.importFailed)
        }
    }

    // MARK: - Export

    func exportPDF(mode: PDFExportMode) async {
        guard let scan else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            exportedFile = try await pdfExporter.export(scan: scan, mode: mode, options: settings.exportOptions)
        } catch {
            present(error, fallback: AppError.export)
        }
    }

    func exportText() async {
        guard let scan else { return }
        do {
            exportedFile = try await pdfExporter.exportText(scan: scan)
        } catch {
            present(error, fallback: AppError.export)
        }
    }

    func dismissShareSheet() {
        exportedFile = nil
    }

    func dismissError() {
        activeErrorMessage = nil
    }

    // MARK: - Helpers

    /// Runs a repository write, reloads, and notifies other screens. Returns whether it succeeded.
    @discardableResult
    private func perform(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            await didChange()
            return true
        } catch {
            present(error, fallback: AppError.persistence)
            await load()
            return false
        }
    }

    private func replaceImage(of pageID: UUID, resetsOCR: Bool, transform: (ScanPage) async throws -> Data) async {
        guard let page = page(for: pageID) else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let newImage = try await transform(page)
            let processed = try await imageProcessor.applying(page.enhancement, to: newImage)
            let thumbnail = try await imageProcessor.thumbnail(from: processed ?? newImage)
            let update = PageImageUpdate(imageData: newImage, processedImageData: processed,
                                         enhancement: page.enhancement, thumbnailData: thumbnail, resetsOCR: resetsOCR)
            try await repository.replacePageImage(scanID: scanID, pageID: pageID, update: update)
            await didChange()
            if resetsOCR, let updated = self.page(for: pageID) {
                startOCR(for: [updated])
            }
        } catch {
            present(error, fallback: AppError.imageProcessing)
        }
    }

    private func didChange() async {
        await load()
        events.libraryDidChange()
    }

    private func startOCR(for pages: [ScanPage]) {
        let scanID = scanID
        Task {
            let outcome = await ocrCoordinator.recognize(scanID: scanID, pages: pages, suggestTitle: false)
            if outcome == .saveFailed {
                present(message: "The page was saved, but its text could not be stored.")
            }
        }
    }

    private func present(_ error: Error, fallback: (String) -> AppError) {
        present(AppError.wrap(error, as: fallback))
    }

    private func present(_ error: AppError) {
        Logger.ui.error("Scan detail error: \(error.debugDetail, privacy: .public)")
        activeErrorMessage = error.localizedDescription
    }

    private func present(message: String) {
        activeErrorMessage = message
    }
}
