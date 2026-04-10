import Foundation

enum PDFExportMode: Sendable {
    case imageOnly
    case searchable
}

protocol PDFExporting {
    func export(scan: ScanDocument, mode: PDFExportMode) throws -> ExportedFile
    func exportText(scan: ScanDocument) throws -> ExportedFile
}
