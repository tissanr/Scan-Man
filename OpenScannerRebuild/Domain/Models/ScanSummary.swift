import Foundation

/// A lightweight library entry: everything the home list and search need, without page images.
nonisolated struct ScanSummary: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    let title: String
    let pageCount: Int
    let previewText: String
    let thumbnailData: Data?
    /// Normalized (case- and diacritic-folded) title, notes and page text.
    let searchText: String

    func matches(_ query: String) -> Bool {
        let normalizedQuery = ScanSearchIndex.normalize(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return normalizedQuery.isEmpty || searchText.contains(normalizedQuery)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ScanSummary {
    nonisolated init(scan: ScanDocument) {
        self.init(
            id: scan.id,
            createdAt: scan.createdAt,
            updatedAt: scan.updatedAt,
            title: scan.title,
            pageCount: scan.pages.count,
            previewText: scan.previewText,
            thumbnailData: scan.orderedPages.first?.thumbnailData,
            searchText: scan.searchText
        )
    }
}
