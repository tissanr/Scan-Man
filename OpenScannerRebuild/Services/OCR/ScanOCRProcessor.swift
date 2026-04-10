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
        let pageResults = await withTaskGroup(of: OCRPageResult.self) { group in
            for page in scan.pages {
                group.addTask {
                    do {
                        let content = try await recognizer.recognizePage(in: page.imageData)
                        return OCRPageResult(order: page.order, content: content, didFail: false)
                    } catch {
                        return OCRPageResult(order: page.order, content: nil, didFail: true)
                    }
                }
            }

            var results: [OCRPageResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        let failedPageCount = pageResults.filter(\.didFail).count
        let processedPages = scan.pages.map { page in
            var updated = page
            let result = pageResults.first(where: { $0.order == page.order })
            updated.recognizedText = result?.content?.text ?? ""
            updated.textObservations = result?.content?.observations ?? []
            return updated
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

private struct OCRPageResult {
    let order: Int
    let content: OCRPageContent?
    let didFail: Bool
}
