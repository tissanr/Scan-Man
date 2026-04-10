import Foundation
import UIKit

enum AppSeeder {
    static func seedIfNeeded(using repository: ScanRepository) async {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--ui-testing-empty") {
            try? await repository.deleteAll()
            return
        }

        guard arguments.contains("--ui-testing-seed-scan") else {
            return
        }

        let existing = (try? await repository.fetchScans()) ?? []
        guard existing.isEmpty else {
            return
        }

        let page = ScanPage(
            id: UUID(),
            order: 0,
            createdAt: Date(),
            imageData: Self.seedImageData(),
            thumbnailData: Self.seedImageData(size: CGSize(width: 120, height: 160)),
            recognizedText: "Invoice 2048\nOpen Scanner seeded document",
            textObservations: []
        )

        let scan = ScanDocument(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            title: "Seeded Invoice",
            pages: [page]
        )

        try? await repository.save(scan: scan)
    }

    private static func seedImageData(size: CGSize = CGSize(width: 800, height: 1100)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(18, size.width * 0.04), weight: .semibold),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]

            NSString(string: "Open Scanner\nSeeded Sample").draw(
                in: CGRect(x: 40, y: 60, width: size.width - 80, height: 200),
                withAttributes: attributes
            )
        }

        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
