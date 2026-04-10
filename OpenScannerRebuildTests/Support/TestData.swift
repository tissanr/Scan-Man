import Foundation
import UIKit
@testable import OpenScannerRebuild

enum TestData {
    static func scan(title: String, pages: [ScanPage]) -> ScanDocument {
        ScanDocument(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            title: title,
            pages: pages
        )
    }

    static func page(order: Int, text: String) -> ScanPage {
        let imageData = makeImageData(label: "Page \(order + 1)")
        let thumbnailData = makeImageData(label: "Thumb \(order + 1)", size: CGSize(width: 120, height: 160))
        return ScanPage(
            id: UUID(),
            order: order,
            createdAt: Date(),
            imageData: imageData,
            thumbnailData: thumbnailData,
            recognizedText: text,
            textObservations: []
        )
    }

    static func uiImage(label: String, size: CGSize = CGSize(width: 600, height: 900)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .medium),
                .foregroundColor: UIColor.black
            ]

            NSString(string: label).draw(at: CGPoint(x: 40, y: 40), withAttributes: attributes)
        }
    }

    private static func makeImageData(label: String, size: CGSize = CGSize(width: 600, height: 900)) -> Data {
        uiImage(label: label, size: size).jpegData(compressionQuality: 0.9) ?? Data()
    }
}
