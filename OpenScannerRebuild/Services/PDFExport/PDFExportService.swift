import CoreGraphics
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

                if mode == .searchable, !page.recognizedText.isEmpty {
                    let hiddenTextColor = UIColor.black.withAlphaComponent(0.02)
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: hiddenTextColor
                    ]

                    NSString(string: page.recognizedText).draw(
                        in: imageRect.insetBy(dx: 12, dy: 12),
                        withAttributes: attributes
                    )
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
        return trimmed.isEmpty ? "OpenScannerExport" : trimmed.replacingOccurrences(of: "/", with: "-")
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
}
