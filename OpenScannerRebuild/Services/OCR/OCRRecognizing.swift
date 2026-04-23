import Foundation

/// A protocol defining the interface for Optical Character Recognition services.
///
/// Use this protocol to implement services that can extract text and layout information from images.
protocol OCRRecognizing {
    /// Performs text recognition on the provided image data.
    ///
    /// - Parameter imageData: The raw data of the image to be processed (e.g., JPEG or PNG).
    /// - Returns: An ``OCRPageContent`` object containing the extracted text and layout observations.
    /// - Throws: An error if the recognition process fails or the image data is invalid.
    func recognizePage(in imageData: Data) async throws -> OCRPageContent
}

/// A container for the results of an OCR operation on a single page.
///
/// This struct holds both the aggregated text and the detailed spatial observations.
struct OCRPageContent: Equatable, Sendable {
    /// The full text extracted from the page, typically joined by newlines.
    let text: String
    
    /// The collection of individual text observations with their bounding boxes.
    let observations: [OCRTextObservation]
}
