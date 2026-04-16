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

    var notes: String {
        get { scan.notes }
        set {
            var updated = scan
            updated.notes = newValue
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

    func saveNotes() async -> Bool {
        let trimmedNotes = scan.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalScan = scan
        var updatedScan = scan
        updatedScan.notes = trimmedNotes
        updatedScan.updatedAt = Date()
        scan = updatedScan

        do {
            try await repository.updateNotes(scanID: scan.id, notes: trimmedNotes)
            return true
        } catch {
            scan = originalScan
            activeErrorMessage = "Unable to save notes."
            return false
        }
    }

    func page(for pageID: UUID) -> ScanPage? {
        scan.pages.first(where: { $0.id == pageID })
    }

    func updateRecognizedText(for pageID: UUID, text: String) async -> Bool {
        let normalizedText = text.normalizedOCRText
        guard let index = scan.pages.firstIndex(where: { $0.id == pageID }) else {
            activeErrorMessage = "Unable to find that page."
            return false
        }

        let originalScan = scan
        let originalPage = scan.pages[index]
        var updatedScan = scan
        updatedScan.pages[index].recognizedText = normalizedText
        updatedScan.updatedAt = Date()
        scan = updatedScan

        do {
            try await repository.updateRecognizedText(scanID: scan.id, pageID: pageID, text: normalizedText)
            return true
        } catch {
            var revertedScan = scan
            if let currentIndex = revertedScan.pages.firstIndex(where: { $0.id == pageID }) {
                revertedScan.pages[currentIndex] = originalPage
                revertedScan.updatedAt = originalScan.updatedAt
            }
            scan = revertedScan
            activeErrorMessage = "Unable to save extracted text."
            return false
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
