import Foundation

protocol OCRRecognizing {
    func recognizePage(in imageData: Data) async throws -> OCRPageContent
}

struct OCRPageContent: Equatable, Sendable {
    let text: String
    let observations: [OCRTextObservation]
}
