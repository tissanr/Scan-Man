import Foundation

/// OCR output for one page, applied with ``ScanRepository/applyOCRResults(scanID:results:suggestedTitle:)``.
nonisolated struct PageOCRResult: Equatable, Sendable {
    let pageID: UUID
    let text: String
    let observations: [OCRTextObservation]
}

/// A new image for an existing page (after rotate, crop or a filter change).
nonisolated struct PageImageUpdate: Equatable, Sendable {
    var imageData: Data
    var processedImageData: Data?
    var enhancement: ImageEnhancement
    var thumbnailData: Data
    /// Clears text and layout because the page geometry changed (rotate/crop).
    var resetsOCR: Bool
}

/// Storage for scans.
///
/// Every mutation is targeted (title, notes, one page, ...) so concurrent edits and background OCR
/// never overwrite each other's changes.
nonisolated protocol ScanRepository: Sendable {
    /// Lightweight entries for the library list, newest first. Does not load page images.
    func fetchSummaries() async throws -> [ScanSummary]

    /// A complete scan including page images, or nil if it does not exist.
    func fetchScan(id: UUID) async throws -> ScanDocument?

    /// Inserts a new scan, or fully replaces an existing one.
    func save(scan: ScanDocument) async throws

    func updateTitle(scanID: UUID, title: String) async throws
    func updateNotes(scanID: UUID, notes: String) async throws
    func updateRecognizedText(scanID: UUID, pageID: UUID, text: String) async throws

    /// Stores OCR output for pages that still exist. Text the user already entered is kept, and the
    /// title is only replaced while it is still an app-generated placeholder. No-op if the scan was deleted.
    func applyOCRResults(scanID: UUID, results: [PageOCRResult], suggestedTitle: String?) async throws

    /// Appends pages after the current last page; their `order` values are reassigned.
    func appendPages(scanID: UUID, pages: [ScanPage]) async throws

    /// Deletes a page. Throws ``AppError/lastPageCannotBeDeleted`` for a scan's only page.
    func deletePage(scanID: UUID, pageID: UUID) async throws

    /// Rewrites page order to match `orderedPageIDs`.
    func reorderPages(scanID: UUID, orderedPageIDs: [UUID]) async throws

    func replacePageImage(scanID: UUID, pageID: UUID, update: PageImageUpdate) async throws

    func delete(scanID: UUID) async throws
    func deleteAll() async throws

    /// Fills summary fields for scans stored by older app versions. Returns how many scans were updated.
    @discardableResult
    func rebuildDerivedFieldsIfNeeded() async throws -> Int
}
