import Foundation

protocol TitleSuggesting {
    func suggestTitle(for pages: [ScanPage]) -> String
}

struct TitleSuggestionService: TitleSuggesting {
    func suggestTitle(for pages: [ScanPage]) -> String {
        for page in pages.sorted(by: { $0.order < $1.order }) {
            let candidate = page.recognizedText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { $0.count >= 3 }

            if let candidate, !candidate.isEmpty {
                return String(candidate.prefix(60))
            }
        }

        return "Untitled Scan"
    }
}
