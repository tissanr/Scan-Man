import Foundation
import OSLog

nonisolated struct ScanOCRProcessingResult: Equatable, Sendable {
    let pageResults: [PageOCRResult]
    let failedPageIDs: [UUID]
    let suggestedTitle: String?

    var failedPageCount: Int { failedPageIDs.count }
}

/// Runs OCR over a set of pages.
nonisolated protocol ScanOCRProcessing: Sendable {
    func process(pages: [ScanPage], suggestTitle: Bool) async -> ScanOCRProcessingResult
}

nonisolated struct ScanOCRProcessor: ScanOCRProcessing {
    let recognizer: OCRRecognizing
    let titleSuggester: TitleSuggesting

    /// Pages are processed one at a time: Vision already uses several cores per page, and running
    /// many pages at once mostly multiplies peak memory for long documents.
    func process(pages: [ScanPage], suggestTitle: Bool) async -> ScanOCRProcessingResult {
        var results: [PageOCRResult] = []
        var failed: [UUID] = []

        for page in pages.sorted(by: { $0.order < $1.order }) {
            if Task.isCancelled { break }
            do {
                // OCR the unfiltered original; filters can remove faint text.
                let content = try await recognizer.recognizePage(in: page.imageData)
                results.append(PageOCRResult(pageID: page.id, text: content.text, observations: content.observations))
            } catch {
                Logger.ocr.error("OCR failed for a page: \(error.localizedDescription, privacy: .public)")
                failed.append(page.id)
            }
        }

        let title = suggestTitle ? titleSuggester.suggestTitle(for: results.map(\.text)) : nil
        return ScanOCRProcessingResult(pageResults: results, failedPageIDs: failed, suggestedTitle: title)
    }
}
