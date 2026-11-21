import Foundation

/// Extracts text and layout from a page image.
nonisolated protocol OCRRecognizing: Sendable {
    /// - Parameter imageData: Encoded image (JPEG, PNG, HEIC...).
    /// - Returns: Text in Vision's order plus per-line geometry.
    func recognizePage(in imageData: Data) async throws -> OCRPageContent
}

/// OCR output for a single page.
nonisolated struct OCRPageContent: Equatable, Sendable {
    /// All lines joined by newlines.
    let text: String
    /// Individual lines with normalized bounding boxes (origin bottom-left).
    let observations: [OCRTextObservation]
}
