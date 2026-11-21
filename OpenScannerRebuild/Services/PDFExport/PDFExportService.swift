import CoreGraphics
import CoreText
import Foundation
import ImageIO
import OSLog

nonisolated struct PDFExportService: PDFExporting {
    let imageProcessor: ImageProcessing

    /// Longest page side, in points, for ``PDFPageSize/fitToImage`` (matches A4).
    static let fitLongSide: CGFloat = 841.89

    func export(scan: ScanDocument, mode: PDFExportMode, options: PDFExportOptions) async throws -> ExportedFile {
        do {
            // Re-encode images first (off the main actor) so the PDF embeds compact JPEGs.
            var images: [Data] = []
            for page in scan.orderedPages {
                images.append(try await imageProcessor.exportJPEG(from: page.displayImageData, quality: options.quality))
            }
            let url = try ExportDirectory.makeFileURL(title: scan.title, pathExtension: "pdf")
            try await Self.writePDF(scan: scan, images: images, mode: mode, pageSize: options.pageSize, to: url)
            return ExportedFile(url: url, filename: url.lastPathComponent)
        } catch {
            let appError = AppError.wrap(error, as: AppError.export)
            Logger.pdf.error("PDF export failed: \(appError.debugDetail, privacy: .public)")
            throw appError
        }
    }

    func exportText(scan: ScanDocument) async throws -> ExportedFile {
        do {
            let url = try ExportDirectory.makeFileURL(title: scan.title, pathExtension: "txt")
            let content = scan.orderedPages.map(\.recognizedText).joined(separator: "\n\n")
            try content.write(to: url, atomically: true, encoding: .utf8)
            return ExportedFile(url: url, filename: url.lastPathComponent)
        } catch {
            let appError = AppError.wrap(error, as: AppError.export)
            Logger.pdf.error("Text export failed: \(appError.debugDetail, privacy: .public)")
            throw appError
        }
    }

    // MARK: - Layout

    /// The PDF page rectangle and where the image goes on it.
    static func layout(imageSize: CGSize, pageSize: PDFPageSize) -> (page: CGRect, image: CGRect) {
        guard imageSize.width > 0, imageSize.height > 0 else {
            let paper = pageSize.paperSize ?? CGSize(width: 595.28, height: 841.89)
            let rect = CGRect(origin: .zero, size: paper)
            return (rect, rect)
        }

        guard let paper = pageSize.paperSize else {
            let scale = fitLongSide / max(imageSize.width, imageSize.height)
            let rect = CGRect(x: 0, y: 0, width: imageSize.width * scale, height: imageSize.height * scale)
            return (rect, rect)
        }

        // Match paper orientation to the image.
        let landscape = imageSize.width > imageSize.height
        let paperSize = landscape ? CGSize(width: paper.height, height: paper.width) : paper
        let page = CGRect(origin: .zero, size: paperSize)
        let scale = min(paperSize.width / imageSize.width, paperSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let image = CGRect(x: (paperSize.width - size.width) / 2, y: (paperSize.height - size.height) / 2,
                           width: size.width, height: size.height)
        return (page, image)
    }

    // MARK: - Writing

    @concurrent
    private static func writePDF(scan: ScanDocument, images: [Data], mode: PDFExportMode, pageSize: PDFPageSize, to url: URL) async throws {
        let auxiliaryInfo: [CFString: Any] = [
            kCGPDFContextTitle: scan.title,
            kCGPDFContextCreator: "Scan Man"
        ]
        var defaultBox = CGRect(origin: .zero, size: pageSize.paperSize ?? CGSize(width: 595.28, height: 841.89))
        guard let context = CGContext(url as CFURL, mediaBox: &defaultBox, auxiliaryInfo as CFDictionary) else {
            throw AppError.export("Could not create PDF context")
        }

        for (page, imageData) in zip(scan.orderedPages, images) {
            let cgImage = CGImageSourceCreateWithData(imageData as CFData, nil)
                .flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            let imageSize = cgImage.map { CGSize(width: $0.width, height: $0.height) } ?? .zero
            let (pageRect, imageRect) = layout(imageSize: imageSize, pageSize: pageSize)

            var mediaBox = pageRect
            let boxData = Data(bytes: &mediaBox, count: MemoryLayout<CGRect>.size) as CFData
            context.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)

            if let cgImage {
                context.interpolationQuality = .high
                context.draw(cgImage, in: imageRect)
            }

            if mode == .searchable {
                SearchableTextLayer.draw(page: page, in: imageRect, context: context)
            }

            context.endPDFPage()
        }

        context.closePDF()
    }
}

/// Draws OCR text invisibly so PDF viewers can search and select it.
nonisolated enum SearchableTextLayer {
    static func draw(page: ScanPage, in imageRect: CGRect, context: CGContext) {
        context.saveGState()
        context.setTextDrawingMode(.invisible)
        defer { context.restoreGState() }

        if page.textMatchesLayout {
            // One positioned line per OCR observation, stretched to its box.
            for observation in page.orderedTextObservations {
                let box = observation.boundingBox
                // Vision boxes and PDF space both use a bottom-left origin.
                let rect = CGRect(
                    x: imageRect.minX + imageRect.width * box.x,
                    y: imageRect.minY + imageRect.height * box.y,
                    width: imageRect.width * box.width,
                    height: imageRect.height * box.height
                )
                drawLine(observation.text, in: rect, context: context, stretchToWidth: true)
            }
        } else if !page.recognizedText.isEmpty {
            // Edited or layout-less text: spread lines evenly down the page so every line is included.
            let lines = page.recognizedText.normalizedOCRText.components(separatedBy: "\n")
            let lineHeight = imageRect.height / CGFloat(max(lines.count, 1))
            for (index, line) in lines.enumerated() {
                let rect = CGRect(
                    x: imageRect.minX,
                    y: imageRect.maxY - lineHeight * CGFloat(index + 1),
                    width: imageRect.width,
                    height: lineHeight
                )
                drawLine(line, in: rect, context: context, stretchToWidth: false)
            }
        }
    }

    private static func drawLine(_ text: String, in rect: CGRect, context: CGContext, stretchToWidth: Bool) {
        guard !text.isEmpty, rect.width > 1, rect.height > 0.5 else { return }

        let fontSize = max(1, min(rect.height * 0.85, 72))
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
        guard width > 0 else { return }

        var scaleX = rect.width / width
        if !stretchToWidth {
            scaleX = min(scaleX, 1)
        }

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: rect.minX, y: rect.minY + descent)
        context.scaleBy(x: scaleX, y: 1)
        context.textPosition = .zero
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

/// Exports go into one temporary folder that is emptied before each export and on launch.
nonisolated enum ExportDirectory {
    static var url: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Exports", isDirectory: true)
    }

    static func makeFileURL(title: String, pathExtension: String) throws -> URL {
        cleanUp()
        // A unique subfolder keeps the human-readable filename while avoiding collisions.
        let folder = url.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(sanitizedFilename(title)).appendingPathExtension(pathExtension)
    }

    static func cleanUp() {
        try? FileManager.default.removeItem(at: url)
    }

    static func sanitizedFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned = title.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return cleaned.isEmpty ? "Scan Man Export" : String(cleaned.prefix(100))
    }
}
