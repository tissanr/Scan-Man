import CoreGraphics
import CoreText
import Foundation
import PDFKit
import UIKit

struct PDFExportService: PDFExporting {
    func export(scan: ScanDocument, mode: PDFExportMode) throws -> ExportedFile {
        let outputURL = try makeOutputURL(filename: sanitizedFilename(from: scan.title), pathExtension: "pdf")
        let document = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))

        try document.writePDF(to: outputURL) { context in
            for page in scan.pages.sorted(by: { $0.order < $1.order }) {
                context.beginPage()

                guard let image = UIImage(data: page.imageData) else {
                    continue
                }

                let pageBounds = CGRect(x: 24, y: 24, width: 564, height: 744)
                let imageRect = fittedRect(for: image.size, in: pageBounds)
                image.draw(in: imageRect)

                if mode == .searchable {
                    drawSearchableText(for: page, in: imageRect, context: context.cgContext)
                }
            }
        }

        return ExportedFile(url: outputURL, filename: outputURL.lastPathComponent)
    }

    func exportText(scan: ScanDocument) throws -> ExportedFile {
        let outputURL = try makeOutputURL(filename: sanitizedFilename(from: scan.title), pathExtension: "txt")
        let content = scan.pages
            .sorted(by: { $0.order < $1.order })
            .map(\.recognizedText)
            .joined(separator: "\n\n")
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
        return ExportedFile(url: outputURL, filename: outputURL.lastPathComponent)
    }

    private func makeOutputURL(filename: String, pathExtension: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent(filename).appendingPathExtension(pathExtension)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func sanitizedFilename(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Scan Man Export" : trimmed.replacingOccurrences(of: "/", with: "-")
    }

    /// Draws an invisible, selectable text layer over the page image.
    ///
    /// When the stored OCR geometry still matches the page text, each line is placed on its
    /// bounding box. If the text was edited after OCR, the geometry is stale, so the edited
    /// text is embedded as a single block instead. Either way the text appears exactly once.
    private func drawSearchableText(for page: ScanPage, in imageRect: CGRect, context: CGContext) {
        let observations = page.orderedTextObservations.filter { !$0.text.isEmpty }
        let observationText = observations.map(\.text).joined(separator: "\n").normalizedOCRText

        context.saveGState()
        context.setTextDrawingMode(.invisible)
        defer { context.restoreGState() }

        if !observations.isEmpty, observationText == page.recognizedText {
            for observation in observations {
                let rect = observationRect(for: observation.boundingBox, in: imageRect)
                guard rect.width > 1, rect.height > 1 else {
                    continue
                }
                drawInvisibleLine(observation.text, fittedTo: rect, context: context)
            }
            return
        }

        guard !page.recognizedText.isEmpty else {
            return
        }

        let lines = page.recognizedText.components(separatedBy: .newlines)
        let lineHeight = min(12, imageRect.height / CGFloat(max(lines.count, 1)))
        for (index, line) in lines.enumerated() {
            let rect = CGRect(
                x: imageRect.minX,
                y: imageRect.minY + CGFloat(index) * lineHeight,
                width: imageRect.width,
                height: lineHeight
            )
            drawInvisibleLine(line, fittedTo: rect, context: context, stretchToWidth: false)
        }
    }

    /// Draws one line of text so its glyph run covers `rect`, which lets PDF viewers highlight
    /// the matching region of the scanned image when the text is searched or selected.
    private func drawInvisibleLine(_ text: String, fittedTo rect: CGRect, context: CGContext, stretchToWidth: Bool = true) {
        let fontSize = max(1, rect.height * 0.85)
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let attributed = NSAttributedString(string: text, attributes: [.font: font])
        let line = CTLineCreateWithAttributedString(attributed)
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        guard lineWidth > 0 else {
            return
        }

        let horizontalScale = stretchToWidth ? rect.width / lineWidth : min(1, rect.width / lineWidth)

        // UIGraphicsPDFRenderer uses a flipped (top-left origin) coordinate space, so the text
        // matrix is flipped back before drawing to keep glyphs upright for extraction.
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY - CTFontGetDescent(font))
        context.scaleBy(x: horizontalScale, y: -1)
        context.textPosition = .zero
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func fittedRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    private func observationRect(for boundingBox: OCRBoundingBox, in drawnImageRect: CGRect) -> CGRect {
        CGRect(
            x: drawnImageRect.minX + (drawnImageRect.width * boundingBox.x),
            y: drawnImageRect.minY + (drawnImageRect.height * (1 - boundingBox.y - boundingBox.height)),
            width: drawnImageRect.width * boundingBox.width,
            height: drawnImageRect.height * boundingBox.height
        )
    }
}
