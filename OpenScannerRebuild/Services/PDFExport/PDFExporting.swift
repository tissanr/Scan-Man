import Foundation

/// Writes scans to shareable files.
nonisolated protocol PDFExporting: Sendable {
    /// Writes a PDF of `scan`. Searchable mode adds an invisible text layer aligned to the page images.
    func export(scan: ScanDocument, mode: PDFExportMode, options: PDFExportOptions) async throws -> ExportedFile

    /// Writes the recognized text of all pages, in page order, as a UTF-8 text file.
    func exportText(scan: ScanDocument) async throws -> ExportedFile
}
