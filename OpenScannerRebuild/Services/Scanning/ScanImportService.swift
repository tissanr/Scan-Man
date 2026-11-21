import CoreGraphics
import Foundation
import PDFKit

nonisolated struct ScanImportService: ScanImporting {
    let imageProcessor: ImageProcessing

    /// Longest side, in pixels, when rasterizing PDF pages.
    private static let pdfRenderMaxDimension: CGFloat = 2200

    func makeScanDocument(fromImageData imageData: [Data], createdAt: Date, options: ImportOptions) async throws -> ScanDocument {
        let pages = try await makePages(fromImageData: imageData, startingOrder: 0, createdAt: createdAt, options: options)
        return makeDocument(with: pages, createdAt: createdAt)
    }

    func makeScanDocument(fromPDFData pdfData: Data, createdAt: Date, options: ImportOptions) async throws -> ScanDocument {
        var pages: [ScanPage] = []
        let pageCount = try await Self.pdfPageCount(pdfData)
        // Render one page at a time to keep peak memory low for long PDFs.
        for index in 0..<pageCount {
            let rendered = try await Self.renderPDFPage(pdfData, at: index)
            pages.append(try await makePage(from: rendered, order: index, createdAt: createdAt, options: options))
        }
        return makeDocument(with: pages, createdAt: createdAt)
    }

    func makePages(fromImageData imageData: [Data], startingOrder: Int, createdAt: Date, options: ImportOptions) async throws -> [ScanPage] {
        guard !imageData.isEmpty else {
            throw ScanImportError.noPages
        }

        var pages: [ScanPage] = []
        for (index, data) in imageData.enumerated() {
            do {
                pages.append(try await makePage(from: data, order: startingOrder + index, createdAt: createdAt, options: options))
            } catch {
                throw ScanImportError.unreadableImage(pageIndex: index)
            }
        }
        return pages
    }

    // MARK: - Helpers

    private func makeDocument(with pages: [ScanPage], createdAt: Date) -> ScanDocument {
        ScanDocument(
            id: UUID(),
            createdAt: createdAt,
            updatedAt: createdAt,
            title: ScanDefaults.defaultTitle(for: createdAt),
            notes: "",
            pages: pages
        )
    }

    private func makePage(from data: Data, order: Int, createdAt: Date, options: ImportOptions) async throws -> ScanPage {
        let original = try await imageProcessor.normalizedPageImage(from: data, quality: options.quality)
        let processed = try await imageProcessor.applying(options.enhancement, to: original)
        let thumbnail = try await imageProcessor.thumbnail(from: processed ?? original)

        return ScanPage(
            id: UUID(),
            order: order,
            createdAt: createdAt,
            imageData: original,
            processedImageData: processed,
            enhancement: options.enhancement,
            thumbnailData: thumbnail,
            recognizedText: "",
            textObservations: []
        )
    }

    @concurrent
    private static func pdfPageCount(_ pdfData: Data) async throws -> Int {
        guard let document = PDFDocument(data: pdfData), !document.isLocked, document.pageCount > 0 else {
            throw ScanImportError.invalidPDF
        }
        return document.pageCount
    }

    @concurrent
    private static func renderPDFPage(_ pdfData: Data, at index: Int) async throws -> Data {
        guard let document = PDFDocument(data: pdfData), let page = document.page(at: index) else {
            throw ScanImportError.pdfPageRenderingFailed(pageIndex: index)
        }

        let bounds = page.bounds(for: .mediaBox)
        // Account for /Rotate so landscape and rotated pages come out upright.
        let rotated = page.rotation % 180 != 0
        let pageSize = rotated ? CGSize(width: bounds.height, height: bounds.width) : bounds.size
        guard pageSize.width > 0, pageSize.height > 0 else {
            throw ScanImportError.pdfPageRenderingFailed(pageIndex: index)
        }

        let scale = min(pdfRenderMaxDimension / max(pageSize.width, pageSize.height), 3)
        let width = Int((pageSize.width * scale).rounded())
        let height = Int((pageSize.height * scale).rounded())
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw ScanImportError.pdfPageRenderingFailed(pageIndex: index)
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        // PDFPage.draw applies the page rotation for us.
        page.draw(with: .mediaBox, to: context)

        guard let cgImage = context.makeImage() else {
            throw ScanImportError.pdfPageRenderingFailed(pageIndex: index)
        }
        let image = CIImage(cgImage: cgImage)
        return try CoreImageProcessor.encode(image, maxDimension: nil, jpegQuality: 0.92)
    }
}
