import Foundation

struct ScanOCRProcessingResult {
    let scan: ScanDocument
    let failedPageCount: Int
}

protocol ScanOCRProcessing {
    func process(scan: ScanDocument) async -> ScanOCRProcessingResult
}

struct ScanOCRProcessor: ScanOCRProcessing {
    let recognizer: OCRRecognizing
    let titleSuggester: TitleSuggesting

    func process(scan: ScanDocument) async -> ScanOCRProcessingResult {
        var failedPageCount = 0
        let processedPages = await withTaskGroup(of: (Int, String?, Bool).self) { group in
            for page in scan.pages {
                group.addTask {
                    do {
                        let text = try await recognizer.recognizeText(in: page.imageData)
                        return (page.order, text.normalizedOCRText, false)
                    } catch {
                        return (page.order, nil, true)
                    }
                }
            }

            var recognizedByOrder: [Int: String] = [:]
            for await result in group {
                if result.2 {
                    failedPageCount += 1
                }
                if let text = result.1 {
                    recognizedByOrder[result.0] = text
                }
            }

            return scan.pages.map { page in
                var updated = page
                updated.recognizedText = recognizedByOrder[page.order] ?? ""
                return updated
            }
        }

        var updatedScan = scan
        updatedScan.pages = processedPages.sorted(by: { $0.order < $1.order })

        let suggestedTitle = titleSuggester.suggestTitle(for: updatedScan.pages)
        if shouldReplaceTitle(updatedScan.title) && suggestedTitle != "Untitled Scan" {
            updatedScan.title = suggestedTitle
        }
        updatedScan.updatedAt = Date()

        return ScanOCRProcessingResult(scan: updatedScan, failedPageCount: failedPageCount)
    }

    private func shouldReplaceTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "Untitled Scan" || trimmed.hasPrefix("Scan ")
    }
}
