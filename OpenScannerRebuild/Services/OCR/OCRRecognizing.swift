import Foundation

protocol OCRRecognizing {
    func recognizeText(in imageData: Data) async throws -> String
}
