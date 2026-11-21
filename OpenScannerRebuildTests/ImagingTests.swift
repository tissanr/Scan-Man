import CoreGraphics
import Foundation
import Testing
@testable import OpenScannerRebuild

@MainActor
struct ImagingTests {
    let processor = CoreImageProcessor()

    @Test
    func normalizingAppliesEXIFOrientation() async throws {
        // Stored 900x600 with "rotate 90° CW" orientation -> displays as 600x900.
        let data = TestData.jpegWithEXIFOrientation(.right, storedSize: CGSize(width: 900, height: 600))
        let normalized = try await processor.normalizedPageImage(from: data, quality: .high)
        #expect(TestData.pixelSize(of: normalized) == CGSize(width: 600, height: 900))
    }

    @Test
    func qualityLimitsResolution() async throws {
        let large = TestData.jpegData(size: CGSize(width: 2000, height: 3000))
        let small = try await processor.normalizedPageImage(from: large, quality: .small)
        let size = try #require(TestData.pixelSize(of: small))
        #expect(max(size.width, size.height) <= ImageQuality.small.maxPixelDimension + 1)
    }

    @Test
    func thumbnailsAreSmall() async throws {
        let thumbnail = try await processor.thumbnail(from: TestData.jpegData())
        let size = try #require(TestData.pixelSize(of: thumbnail))
        #expect(max(size.width, size.height) <= 321)
    }

    @Test
    func rotationSwapsDimensions() async throws {
        let rotated = try await processor.rotated(TestData.jpegData(size: CGSize(width: 600, height: 900)), quarterTurns: 1)
        #expect(TestData.pixelSize(of: rotated) == CGSize(width: 900, height: 600))

        let back = try await processor.rotated(rotated, quarterTurns: -1)
        #expect(TestData.pixelSize(of: back) == CGSize(width: 600, height: 900))
    }

    @Test(arguments: [ImageEnhancement.enhanced, .grayscale, .blackAndWhite])
    func filtersProduceImagesOfTheSameSize(_ enhancement: ImageEnhancement) async throws {
        let original = TestData.jpegData()
        let processed = try #require(try await processor.applying(enhancement, to: original))
        #expect(TestData.pixelSize(of: processed) == TestData.pixelSize(of: original))
    }

    @Test
    func originalFilterKeepsNoProcessedCopy() async throws {
        #expect(try await processor.applying(.original, to: TestData.jpegData()) == nil)
    }

    @Test
    func croppingToHalfTheImageHalvesTheWidth() async throws {
        let quad = DocumentQuad(
            topLeft: CGPoint(x: 0, y: 0), topRight: CGPoint(x: 0.5, y: 0),
            bottomRight: CGPoint(x: 0.5, y: 1), bottomLeft: CGPoint(x: 0, y: 1)
        )
        let cropped = try await processor.cropped(TestData.jpegData(size: CGSize(width: 600, height: 900)), to: quad)
        let size = try #require(TestData.pixelSize(of: cropped))
        #expect(abs(size.width - 300) <= 2)
        #expect(abs(size.height - 900) <= 2)
    }

    @Test
    func unreadableDataThrows() async {
        await #expect(throws: AppError.self) {
            _ = try await processor.normalizedPageImage(from: Data("nope".utf8), quality: .high)
        }
    }

    @Test
    func quadCornersAreClamped() {
        let quad = DocumentQuad.fullImage.settingCorner(2, to: CGPoint(x: 1.4, y: -0.2)).clamped()
        #expect(quad.bottomRight == CGPoint(x: 1, y: 0))
    }
}
