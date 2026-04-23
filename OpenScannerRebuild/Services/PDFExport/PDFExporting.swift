import Foundation

/// Defines the strategy for PDF generation.
enum PDFExportMode: Sendable {
    /// Generates a PDF containing only the scanned images.
    case imageOnly
    /// Generates a PDF with searchable text layers aligned with the scanned images.
    case searchable
}

/// A protocol for services that export scan documents to various formats.
protocol PDFExporting {
    /// Exports a scan document as a PDF file.
    /// - Parameters:
    ///   - scan: The ``ScanDocument`` to export.
    ///   - mode: The ``PDFExportMode`` to use for generation.
    /// - Returns: An ``ExportedFile`` containing the PDF data and a suggested filename.
    /// - Throws: An error if the PDF generation fails.
    func export(scan: ScanDocument, mode: PDFExportMode) throws -> ExportedFile
    
    /// Exports the recognized text from all pages of a scan document as a plain text file.
    /// - Parameter scan: The ``ScanDocument`` to export.
    /// - Returns: An ``ExportedFile`` containing the text data and a suggested filename.
    /// - Throws: An error if the text aggregation fails.
    func exportText(scan: ScanDocument) throws -> ExportedFile
}
