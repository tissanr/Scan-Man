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

    var hasOCRLayout: Bool {
        !textObservations.isEmpty
    }

    var orderedTextObservations: [OCRTextObservation] {
        textObservations.sorted { lhs, rhs in
            lhs.readingOrderComparator < rhs.readingOrderComparator
        }
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

private extension OCRTextObservation {
    var readingOrderComparator: (Double, Double) {
        let top = 1 - boundingBox.y - boundingBox.height
        return (top, boundingBox.x)
    }
}
