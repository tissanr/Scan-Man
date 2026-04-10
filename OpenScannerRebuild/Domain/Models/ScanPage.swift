import Foundation

struct ScanPage: Identifiable, Equatable, Sendable {
    let id: UUID
    let order: Int
    let createdAt: Date
    let imageData: Data
    let thumbnailData: Data
    var recognizedText: String

    var previewText: String {
        recognizedText.normalizedPreview
    }
}
