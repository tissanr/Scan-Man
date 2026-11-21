import Foundation

/// A single scanned page.
///
/// `imageData` is always the upright original (after rotation and crop). Visual filters are
/// stored separately in `processedImageData` so they can be changed or removed later.
nonisolated struct ScanPage: Identifiable, Equatable, Sendable {
    let id: UUID
    var order: Int
    let createdAt: Date
    var imageData: Data
    var processedImageData: Data?
    var enhancement: ImageEnhancement
    var thumbnailData: Data
    var recognizedText: String
    var textObservations: [OCRTextObservation]

    init(
        id: UUID,
        order: Int,
        createdAt: Date,
        imageData: Data,
        processedImageData: Data? = nil,
        enhancement: ImageEnhancement = .original,
        thumbnailData: Data,
        recognizedText: String,
        textObservations: [OCRTextObservation]
    ) {
        self.id = id
        self.order = order
        self.createdAt = createdAt
        self.imageData = imageData
        self.processedImageData = processedImageData
        self.enhancement = enhancement
        self.thumbnailData = thumbnailData
        self.recognizedText = recognizedText
        self.textObservations = textObservations
    }

    /// The image shown to the user and written to exports.
    var displayImageData: Data {
        processedImageData ?? imageData
    }

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

    /// True when the stored text still matches the OCR geometry, i.e. the user has not edited it.
    var textMatchesLayout: Bool {
        guard hasOCRLayout else { return false }
        let layoutLines = Set(textObservations.map(\.text.normalizedOCRText).filter { !$0.isEmpty })
        let textLines = Set(recognizedText.normalizedOCRText.components(separatedBy: "\n").filter { !$0.isEmpty })
        return layoutLines == textLines
    }
}

/// Visual treatment applied to a page image.
nonisolated enum ImageEnhancement: String, Codable, CaseIterable, Identifiable, Sendable {
    case original
    case enhanced
    case grayscale
    case blackAndWhite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .original: "Original"
        case .enhanced: "Enhanced"
        case .grayscale: "Grayscale"
        case .blackAndWhite: "Black & White"
        }
    }
}

nonisolated struct OCRTextObservation: Equatable, Codable, Sendable {
    let text: String
    /// Normalized Vision coordinates (origin bottom-left).
    let boundingBox: OCRBoundingBox
}

nonisolated struct OCRBoundingBox: Equatable, Codable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private extension OCRTextObservation {
    nonisolated var readingOrderComparator: (Double, Double) {
        let top = 1 - boundingBox.y - boundingBox.height
        return (top, boundingBox.x)
    }
}
