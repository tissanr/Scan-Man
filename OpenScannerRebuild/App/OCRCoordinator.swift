import Foundation
import Observation
import OSLog

/// Runs OCR in the background for new or changed pages and stores the results.
@MainActor
@Observable
final class OCRCoordinator {
    enum Outcome: Equatable {
        case completed
        case allPagesFailed
        case saveFailed
    }

    private(set) var activeRuns: [UUID: Int] = [:]

    @ObservationIgnored private let repository: ScanRepository
    @ObservationIgnored private let processor: ScanOCRProcessing
    @ObservationIgnored private let events: LibraryEvents

    init(repository: ScanRepository, processor: ScanOCRProcessing, events: LibraryEvents) {
        self.repository = repository
        self.processor = processor
        self.events = events
    }

    func isRecognizing(scanID: UUID) -> Bool {
        activeRuns[scanID, default: 0] > 0
    }

    /// Recognizes `pages` and merges the results into the stored scan.
    /// - Parameter suggestTitle: Replace a placeholder title with the first meaningful line.
    @discardableResult
    func recognize(scanID: UUID, pages: [ScanPage], suggestTitle: Bool) async -> Outcome {
        guard !pages.isEmpty else { return .completed }

        activeRuns[scanID, default: 0] += 1
        defer {
            activeRuns[scanID, default: 1] -= 1
            if activeRuns[scanID] == 0 { activeRuns[scanID] = nil }
        }

        let result = await processor.process(pages: pages, suggestTitle: suggestTitle)

        do {
            try await repository.applyOCRResults(scanID: scanID, results: result.pageResults, suggestedTitle: result.suggestedTitle)
        } catch {
            Logger.ocr.error("Could not store OCR results: \(error.localizedDescription, privacy: .public)")
            return .saveFailed
        }

        events.libraryDidChange()
        return result.failedPageCount == pages.count ? .allPagesFailed : .completed
    }
}
