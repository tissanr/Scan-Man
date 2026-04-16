import Foundation
import PDFKit
import UIKit

struct ScanImportService: ScanImporting {
    func makeScanDocument(from images: [UIImage], createdAt: Date = Date()) throws -> ScanDocument {
        guard !images.isEmpty else {
            throw ScanImportError.noPages
        }

        let pages = try makePages(from: images, createdAt: createdAt)

        return makeDocument(with: pages, createdAt: createdAt)
    }

    func makeScanDocument(fromPDFData pdfData: Data, createdAt: Date = Date()) throws -> ScanDocument {
        guard let document = PDFDocument(data: pdfData), document.pageCount > 0 else {
            throw ScanImportError.invalidPDF
        }

        let images = try (0..<document.pageCount).map { index in
            guard let page = document.page(at: index) else {
                throw ScanImportError.pdfPageRenderingFailed(pageIndex: index)
            }

            return try renderImage(for: page, pageIndex: index)
        }

        let pages = try makePages(from: images, createdAt: createdAt)

        return makeDocument(with: pages, createdAt: createdAt)
    }

    private static func defaultTitle(for createdAt: Date) -> String {
        "Scan \(createdAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func makeDocument(with pages: [ScanPage], createdAt: Date) -> ScanDocument {
        ScanDocument(
            id: UUID(),
            createdAt: createdAt,
            updatedAt: createdAt,
            title: Self.defaultTitle(for: createdAt),
            notes: "",
            pages: pages
        )
    }

    private func makePages(from images: [UIImage], createdAt: Date) throws -> [ScanPage] {
        try images.enumerated().map { index, image in
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
                recognizedText: "",
                textObservations: []
            )
        }
    }

    private func renderImage(for page: PDFPage, pageIndex: Int) throws -> UIImage {
        let pageBounds = page.bounds(for: .mediaBox).integral
        guard pageBounds.width > 0, pageBounds.height > 0 else {
            throw ScanImportError.pdfPageRenderingFailed(pageIndex: pageIndex)
        }

        let maxDimension: CGFloat = 2200
        let scale = min(maxDimension / max(pageBounds.width, pageBounds.height), 2.0)
        let renderSize = CGSize(width: max(1, pageBounds.width * scale), height: max(1, pageBounds.height * scale))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: renderSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: renderSize))

            let cgContext = context.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: 0, y: renderSize.height)
            cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: cgContext)
            cgContext.restoreGState()
        }
    }
}
