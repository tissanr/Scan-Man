import Foundation

struct ScanPage: Identifiable, Equatable, Sendable {
    let id: UUID
    let order: Int
    let createdAt: Date
    let imageData: Data
    let thumbnailData: Data
    var recognizedText: String
    var textObservations: [OCRTextObservation]

    var previewText: String {
        recognizedText.normalizedPreview
    }
}

struct OCRTextObservation: Equatable, Codable, Sendable {
    let text: String
    let boundingBox: OCRBoundingBox
}

struct OCRBoundingBox: Equatable, Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
