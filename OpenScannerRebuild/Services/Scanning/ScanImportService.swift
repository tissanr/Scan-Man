import Foundation
import UIKit

struct ScanImportService: ScanImporting {
    func makeScanDocument(from images: [UIImage], createdAt: Date = Date()) throws -> ScanDocument {
        guard !images.isEmpty else {
            throw ScanImportError.noPages
        }

        let pages = try images.enumerated().map { index, image in
            guard let imageData = image.jpegData(compressionQuality: 0.92) else {
                throw ScanImportError.imageEncodingFailed(pageIndex: index)
            }

            let thumbnailSize = CGSize(width: 240, height: 320)
            let thumbnail = image.preparingThumbnail(of: thumbnailSize) ?? image
            guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.75) else {
                throw ScanImportError.imageEncodingFailed(pageIndex: index)
            }

            return ScanPage(
                id: UUID(),
                order: index,
                createdAt: createdAt,
                imageData: imageData,
                thumbnailData: thumbnailData,
                recognizedText: ""
            )
        }

        return ScanDocument(
            id: UUID(),
            createdAt: createdAt,
            updatedAt: createdAt,
            title: Self.defaultTitle(for: createdAt),
            pages: pages
        )
    }

    private static func defaultTitle(for createdAt: Date) -> String {
        "Scan \(createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
