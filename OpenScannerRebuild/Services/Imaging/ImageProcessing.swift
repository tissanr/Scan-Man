import CoreGraphics
import Foundation

/// Four corners of a document in normalized image coordinates (origin top-left, 0...1).
nonisolated struct DocumentQuad: Equatable, Sendable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// The whole image.
    static let fullImage = DocumentQuad(
        topLeft: CGPoint(x: 0, y: 0),
        topRight: CGPoint(x: 1, y: 0),
        bottomRight: CGPoint(x: 1, y: 1),
        bottomLeft: CGPoint(x: 0, y: 1)
    )

    var corners: [CGPoint] {
        [topLeft, topRight, bottomRight, bottomLeft]
    }

    /// Clamps every corner into the image.
    func clamped() -> DocumentQuad {
        func clamp(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
        }
        return DocumentQuad(topLeft: clamp(topLeft), topRight: clamp(topRight),
                            bottomRight: clamp(bottomRight), bottomLeft: clamp(bottomLeft))
    }
}

/// Image operations on encoded page images. All results are upright JPEG data.
nonisolated protocol ImageProcessing: Sendable {
    /// Decodes, applies EXIF orientation, downsizes and re-encodes a page image for storage.
    func normalizedPageImage(from data: Data, quality: ImageQuality) async throws -> Data

    /// A small JPEG for lists.
    func thumbnail(from data: Data) async throws -> Data

    /// Applies a visual filter. Returns nil for ``ImageEnhancement/original``.
    func applying(_ enhancement: ImageEnhancement, to data: Data) async throws -> Data?

    /// Rotates by 90° steps; positive is clockwise.
    func rotated(_ data: Data, quarterTurns: Int) async throws -> Data

    /// Crops to `quad` and corrects perspective.
    func cropped(_ data: Data, to quad: DocumentQuad) async throws -> Data

    /// Finds the most likely document outline, if any.
    func detectDocument(in data: Data) async -> DocumentQuad?

    /// Re-encodes for export at the given quality.
    func exportJPEG(from data: Data, quality: ImageQuality) async throws -> Data
}
