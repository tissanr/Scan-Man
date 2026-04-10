import Foundation
import Combine

@MainActor
final class ScanDetailViewModel: ObservableObject {
    private let repository: ScanRepository
    private let pdfExporter: PDFExporting

    @Published private(set) var scan: ScanDocument
    @Published private(set) var activeErrorMessage: String?
    @Published private(set) var exportedFile: ExportedFile?

    init(scan: ScanDocument, repository: ScanRepository, pdfExporter: PDFExporting) {
        self.scan = scan
        self.repository = repository
        self.pdfExporter = pdfExporter
    }

    var title: String {
        get { scan.title }
        set {
            var updated = scan
            updated.title = newValue
            scan = updated
        }
    }

    func saveTitle() async {
        do {
            try await repository.updateTitle(scanID: scan.id, title: scan.title)
        } catch {
            activeErrorMessage = "Unable to rename that scan."
        }
    }

    func refresh() async {
        do {
            if let refreshed = try await repository.fetchScan(id: scan.id) {
                scan = refreshed
            }
        } catch {
            activeErrorMessage = "Unable to refresh this scan."
        }
    }

    func exportPDF(mode: PDFExportMode) {
        do {
            exportedFile = try pdfExporter.export(scan: scan, mode: mode)
        } catch {
            activeErrorMessage = "Unable to export a PDF right now."
        }
    }

    func exportText() {
        do {
            exportedFile = try pdfExporter.exportText(scan: scan)
        } catch {
            activeErrorMessage = "Unable to export text right now."
        }
    }

    func dismissShareSheet() {
        exportedFile = nil
    }

    func dismissError() {
        activeErrorMessage = nil
    }
}
