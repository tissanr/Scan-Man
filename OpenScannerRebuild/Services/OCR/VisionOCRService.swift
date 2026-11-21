import CoreGraphics
import Foundation
import ImageIO
import Vision

nonisolated struct VisionOCRService: OCRRecognizing {
    func recognizePage(in imageData: Data) async throws -> OCRPageContent {
        try await Self.recognize(imageData)
    }

    @concurrent
    private static func recognize(_ imageData: Data) async throws -> OCRPageContent {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AppError.ocr("The scanned image could not be decoded")
        }

        // Respect EXIF orientation so boxes match the image as it is displayed.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        do {
            try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request])
        } catch {
            throw AppError.ocr(error.localizedDescription)
        }

        let observations = (request.results ?? []).compactMap { observation -> OCRTextObservation? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }
            let text = candidate.string.normalizedOCRText
            guard !text.isEmpty else { return nil }
            let box = observation.boundingBox
            return OCRTextObservation(
                text: text,
                boundingBox: OCRBoundingBox(x: box.origin.x, y: box.origin.y, width: box.size.width, height: box.size.height)
            )
        }

        let text = observations.map(\.text).joined(separator: "\n").normalizedOCRText
        return OCRPageContent(text: text, observations: observations)
    }
}
