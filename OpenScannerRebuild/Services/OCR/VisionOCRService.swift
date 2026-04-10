import Foundation
import UIKit
import Vision

struct VisionOCRService: OCRRecognizing {
    func recognizePage(in imageData: Data) async throws -> OCRPageContent {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw OCRServiceError.invalidImageData
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = ((request.results as? [VNRecognizedTextObservation]) ?? [])
                    .compactMap { observation -> OCRTextObservation? in
                        guard let candidate = observation.topCandidates(1).first else {
                            return nil
                        }

                        return OCRTextObservation(
                            text: candidate.string.normalizedOCRText,
                            boundingBox: OCRBoundingBox(
                                x: observation.boundingBox.origin.x,
                                y: observation.boundingBox.origin.y,
                                width: observation.boundingBox.size.width,
                                height: observation.boundingBox.size.height
                            )
                        )
                    }
                    .filter { !$0.text.isEmpty }

                let text = observations
                    .map(\.text)
                    .joined(separator: "\n")
                    .normalizedOCRText

                continuation.resume(returning: OCRPageContent(text: text, observations: observations))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum OCRServiceError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The scanned image could not be processed for OCR."
        }
    }
}
