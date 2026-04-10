import Foundation

struct ScanDocument: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    let updatedAt: Date
    var title: String
    var pages: [ScanPage]

    var previewText: String {
        pages.previewText
    }

    var searchText: String {
        ([title] + pages.map(\.recognizedText))
            .joined(separator: "\n")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

extension ScanDocument: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
