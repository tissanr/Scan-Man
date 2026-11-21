import Foundation

nonisolated protocol TitleSuggesting: Sendable {
    /// A short title from the first meaningful line of text, or nil if there is none.
    func suggestTitle(for pageTexts: [String]) -> String?
}

nonisolated struct TitleSuggestionService: TitleSuggesting {
    func suggestTitle(for pageTexts: [String]) -> String? {
        for text in pageTexts {
            let candidate = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { line in
                    // Skip lines that are mostly numbers or punctuation (dates, page numbers, totals).
                    line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count >= 3
                }

            if let candidate {
                return String(candidate.prefix(60))
            }
        }
        return nil
    }
}
