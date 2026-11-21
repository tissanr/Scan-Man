import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers
import Vision

/// ``ImageProcessing`` built on Core Image, ImageIO and Vision. Safe to use from any thread.
nonisolated struct CoreImageProcessor: ImageProcessing {
    private static let thumbnailMaxDimension: CGFloat = 320

    // CIContext is thread-safe and expensive to create, so share one.
    nonisolated(unsafe) private static let context = CIContext(options: [.cacheIntermediates: false])

    func normalizedPageImage(from data: Data, quality: ImageQuality) async throws -> Data {
        try await Self.normalizedPageImageImpl(from: data, quality: quality)
    }

    @concurrent
    private static func normalizedPageImageImpl(from data: Data, quality: ImageQuality) async throws -> Data {
        let image = try decode(data)
        return try Self.encode(image, maxDimension: quality.maxPixelDimension, jpegQuality: quality.jpegQuality)
    }

    func thumbnail(from data: Data) async throws -> Data {
        try await Self.thumbnailImpl(from: data)
    }

    @concurrent
    private static func thumbnailImpl(from data: Data) async throws -> Data {
        let image = try decode(data)
        return try Self.encode(image, maxDimension: Self.thumbnailMaxDimension, jpegQuality: 0.7)
    }

    func applying(_ enhancement: ImageEnhancement, to data: Data) async throws -> Data? {
        try await Self.applyingImpl(enhancement, to: data)
    }

    @concurrent
    private static func applyingImpl(_ enhancement: ImageEnhancement, to data: Data) async throws -> Data? {
        guard enhancement != .original else { return nil }
        let image = try decode(data)
        let output: CIImage?

        switch enhancement {
        case .original:
            output = image
        case .enhanced:
            let filter = CIFilter.documentEnhancer()
            filter.inputImage = image
            filter.amount = 1
            output = filter.outputImage
        case .grayscale:
            output = Self.grayscale(image, contrast: 1.1)
        case .blackAndWhite:
            let threshold = CIFilter.colorThresholdOtsu()
            threshold.inputImage = Self.grayscale(image, contrast: 1.2)
            output = threshold.outputImage
        }

        guard let output else {
            throw AppError.imageProcessing("Filter \(enhancement.rawValue) produced no image")
        }
        return try Self.encode(output.cropped(to: image.extent), maxDimension: nil, jpegQuality: 0.85)
    }

    func rotated(_ data: Data, quarterTurns: Int) async throws -> Data {
        try await Self.rotatedImpl(data, quarterTurns: quarterTurns)
    }

    @concurrent
    private static func rotatedImpl(_ data: Data, quarterTurns: Int) async throws -> Data {
        let image = try decode(data)
        let turns = ((quarterTurns % 4) + 4) % 4
        let orientation: CGImagePropertyOrientation = switch turns {
        case 1: .right
        case 2: .down
        case 3: .left
        default: .up
        }
        return try Self.encode(image.oriented(orientation), maxDimension: nil, jpegQuality: 0.9)
    }

    func cropped(_ data: Data, to quad: DocumentQuad) async throws -> Data {
        try await Self.croppedImpl(data, to: quad)
    }

    @concurrent
    private static func croppedImpl(_ data: Data, to quad: DocumentQuad) async throws -> Data {
        let image = try decode(data)
        let extent = image.extent
        let q = quad.clamped()

        // Normalized top-left coordinates -> Core Image pixel coordinates (origin bottom-left).
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: extent.minX + p.x * extent.width, y: extent.minY + (1 - p.y) * extent.height)
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = point(q.topLeft)
        filter.topRight = point(q.topRight)
        filter.bottomRight = point(q.bottomRight)
        filter.bottomLeft = point(q.bottomLeft)

        guard let output = filter.outputImage, output.extent.width >= 1, output.extent.height >= 1 else {
            throw AppError.imageProcessing("Perspective correction failed")
        }
        return try Self.encode(output, maxDimension: nil, jpegQuality: 0.9)
    }

    func detectDocument(in data: Data) async -> DocumentQuad? {
        await Self.detectDocumentImpl(in: data)
    }

    @concurrent
    private static func detectDocumentImpl(in data: Data) async -> DocumentQuad? {
        guard let image = try? decode(data),
              let cgImage = Self.context.createCGImage(image, from: image.extent) else {
            return nil
        }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.3
        request.quadratureTolerance = 30

        do {
            try VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
        } catch {
            Logger.imaging.error("Rectangle detection failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard let rectangle = request.results?.first else { return nil }
        // Vision uses a bottom-left origin; flip to top-left.
        func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
        return DocumentQuad(
            topLeft: flip(rectangle.topLeft),
            topRight: flip(rectangle.topRight),
            bottomRight: flip(rectangle.bottomRight),
            bottomLeft: flip(rectangle.bottomLeft)
        )
    }

    func exportJPEG(from data: Data, quality: ImageQuality) async throws -> Data {
        try await Self.exportJPEGImpl(from: data, quality: quality)
    }

    @concurrent
    private static func exportJPEGImpl(from data: Data, quality: ImageQuality) async throws -> Data {
        let image = try decode(data)
        return try Self.encode(image, maxDimension: quality.maxPixelDimension, jpegQuality: quality.jpegQuality)
    }

    // MARK: - Helpers

    /// Decodes image data with its EXIF orientation applied, so the result is upright.
    static func decode(_ data: Data) throws -> CIImage {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else {
            throw AppError.imageProcessing("Unreadable image data")
        }
        // Move the origin to zero so later crops and transforms are simple.
        return image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
    }

    static func encode(_ image: CIImage, maxDimension: CGFloat?, jpegQuality: CGFloat) throws -> Data {
        var output = image
        let longest = max(image.extent.width, image.extent.height)
        if let maxDimension, longest > maxDimension {
            let scale = maxDimension / longest
            let filter = CIFilter.lanczosScaleTransform()
            filter.inputImage = image
            filter.scale = Float(scale)
            filter.aspectRatio = 1
            output = filter.outputImage ?? image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let options: [CIImageRepresentationOption: Any] = [
            CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): jpegQuality
        ]
        guard let data = context.jpegRepresentation(of: output, colorSpace: colorSpace, options: options) else {
            throw AppError.imageProcessing("JPEG encoding failed")
        }
        return data
    }

    private static func grayscale(_ image: CIImage, contrast: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = 0
        filter.contrast = contrast
        return filter.outputImage ?? image
    }
}
