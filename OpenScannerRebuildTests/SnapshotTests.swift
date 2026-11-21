import CoreGraphics
import Foundation
import SwiftUI
import Testing
import UIKit
@testable import OpenScannerRebuild

/// Pixel snapshots of the OCR overlay. Baselines live in `__Snapshots__` next to this file.
///
/// When a baseline is missing the test records it and fails; commit the new PNG and re-run.
/// On a mismatch a `.failed.png` is written beside the baseline for inspection.
@MainActor
struct SnapshotTests {
    @Test
    func ocrOverlayHighlightsLines() throws {
        let page = TestData.page(order: 0, text: "", observations: [
            TestData.observation("Title", x: 0.1, y: 0.8, width: 0.5, height: 0.08),
            TestData.observation("Body", x: 0.1, y: 0.5, width: 0.8, height: 0.05),
            TestData.observation("Footer", x: 0.6, y: 0.05, width: 0.3, height: 0.04)
        ])
        try assertSnapshot(of: overlay(page: page, selected: nil), named: "ocr-overlay")
    }

    @Test
    func ocrOverlayEmphasizesSelectedLine() throws {
        let body = TestData.observation("Body", x: 0.1, y: 0.5, width: 0.8, height: 0.05)
        let page = TestData.page(order: 0, text: "", observations: [
            TestData.observation("Title", x: 0.1, y: 0.8, width: 0.5, height: 0.08),
            body
        ])
        try assertSnapshot(of: overlay(page: page, selected: body.layoutID), named: "ocr-overlay-selected")
    }

    private func overlay(page: ScanPage, selected: String?) -> some View {
        ZStack(alignment: .topLeading) {
            Color.black
            OCRLayoutOverlay(page: page, imageSize: CGSize(width: 600, height: 900),
                             containerSize: CGSize(width: 200, height: 300), selectedObservationID: selected)
        }
        .frame(width: 200, height: 300)
        .environment(\.colorScheme, .light)
        .tint(.blue)
    }

    private func assertSnapshot(of view: some View, named name: String, sourceFile: String = #filePath) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        let png = try #require(UIImage(cgImage: image).pngData())

        let directory = URL(fileURLWithPath: sourceFile).deletingLastPathComponent().appendingPathComponent("__Snapshots__")
        let baselineURL = directory.appendingPathComponent("\(name).png")

        guard let baselineData = try? Data(contentsOf: baselineURL),
              let baseline = UIImage(data: baselineData)?.cgImage else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: baselineURL)
            Issue.record("Recorded new snapshot \(name).png; commit it and re-run.")
            return
        }

        let difference = Self.fractionOfDifferingPixels(image, baseline)
        if difference > 0.005 {
            try? png.write(to: directory.appendingPathComponent("\(name).failed.png"))
            Issue.record("Snapshot \(name) differs in \(String(format: "%.2f", difference * 100))% of pixels")
        }
    }

    /// Share of pixels whose channels differ by more than a small tolerance (1.0 if sizes differ).
    private static func fractionOfDifferingPixels(_ lhs: CGImage, _ rhs: CGImage) -> Double {
        guard lhs.width == rhs.width, lhs.height == rhs.height,
              let a = rgba(lhs), let b = rgba(rhs) else {
            return 1
        }
        var differing = 0
        for pixel in stride(from: 0, to: a.count, by: 4) {
            for channel in 0..<4 where abs(Int(a[pixel + channel]) - Int(b[pixel + channel])) > 16 {
                differing += 1
                break
            }
        }
        return Double(differing) / Double(lhs.width * lhs.height)
    }

    private static func rgba(_ image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }
}
