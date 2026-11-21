import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
@testable import OpenScannerRebuild

@MainActor
enum TestData {
    static func scan(title: String, notes: String = "", createdAt: Date = Date(), pages: [ScanPage]) -> ScanDocument {
        ScanDocument(
            id: UUID(),
            createdAt: createdAt,
            updatedAt: createdAt,
            title: title,
            notes: notes,
            pages: pages
        )
    }

    static func page(order: Int, text: String, observations: [OCRTextObservation] = []) -> ScanPage {
        ScanPage(
            id: UUID(),
            order: order,
            createdAt: Date(),
            imageData: jpegData(label: "Page \(order + 1)"),
            thumbnailData: jpegData(label: "Thumb \(order + 1)", size: CGSize(width: 120, height: 160)),
            recognizedText: text,
            textObservations: observations
        )
    }

    static func observation(_ text: String, x: Double = 0.1, y: Double = 0.5, width: Double = 0.4, height: Double = 0.05) -> OCRTextObservation {
        OCRTextObservation(text: text, boundingBox: OCRBoundingBox(x: x, y: y, width: width, height: height))
    }

    static func uiImage(label: String, size: CGSize = CGSize(width: 600, height: 900)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            NSString(string: label).draw(at: CGPoint(x: 40, y: 40), withAttributes: attributes)
        }
    }

    static func jpegData(label: String = "Page", size: CGSize = CGSize(width: 600, height: 900)) -> Data {
        uiImage(label: label, size: size).jpegData(compressionQuality: 0.9) ?? Data()
    }

    /// JPEG whose pixels are stored sideways with an EXIF orientation tag, like many camera photos.
    static func jpegWithEXIFOrientation(_ orientation: CGImagePropertyOrientation, storedSize: CGSize) -> Data {
        let cgImage = uiImage(label: "EXIF", size: storedSize).cgImage!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    static func pdfData(pageSizes: [CGSize]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSizes.first ?? CGSize(width: 300, height: 400)))
        return renderer.pdfData { context in
            for (index, size) in pageSizes.enumerated() {
                context.beginPage(withBounds: CGRect(origin: .zero, size: size), pageInfo: [:])
                NSString(string: "PDF page \(index + 1)").draw(
                    at: CGPoint(x: 24, y: 24),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
                )
            }
        }
    }

    static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? UInt32) ?? 1
        // Orientations 5-8 swap width and height when displayed.
        return orientation >= 5 ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    static func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ScanManTests.\(UUID().uuidString)")!
    }
}
