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

    @Published private(set) var scans: [ScanDocument] = []
    @Published var searchText = ""
    @Published private(set) var activeErrorMessage: String?
    @Published private(set) var isShowingScanner = false
    @Published private(set) var pendingNavigationScan: ScanDocument?

    init(repository: ScanRepository, titleSuggester: TitleSuggesting, ocrProcessor: ScanOCRProcessing, scanDeviceSupport: ScanDeviceSupporting, scanImporter: ScanImporting) {
        self.repository = repository
        self.titleSuggester = titleSuggester
        self.ocrProcessor = ocrProcessor
        self.scanDeviceSupport = scanDeviceSupport
        self.scanImporter = scanImporter
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

    func load() async {
        do {
            scans = try await repository.fetchScans()
        } catch {
            activeErrorMessage = "Unable to load scans right now."
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

        do {
            let scan = try scanImporter.makeScanDocument(from: images, createdAt: Date())
            try await repository.save(scan: scan)
            scans.insert(scan, at: 0)
            pendingNavigationScan = scan
            Task {
                await processOCR(for: scan)
            }
        } catch {
            activeErrorMessage = error.localizedDescription.isEmpty ? "Open Scanner could not save this scan." : error.localizedDescription
        }
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
}
