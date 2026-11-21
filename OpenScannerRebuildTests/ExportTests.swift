import Foundation
import PDFKit
import Testing
@testable import OpenScannerRebuild

@MainActor
struct ExportTests {
    let exporter = PDFExportService(imageProcessor: CoreImageProcessor())

    private func export(_ scan: ScanDocument, mode: PDFExportMode = .searchable, pageSize: PDFPageSize = .a4) async throws -> PDFDocument {
        let file = try await exporter.export(scan: scan, mode: mode, options: PDFExportOptions(pageSize: pageSize, quality: .medium))
        return try #require(PDFDocument(url: file.url))
    }

    private func occurrences(of needle: String, in document: PDFDocument) -> Int {
        (document.string ?? "").components(separatedBy: needle).count - 1
    }

    @Test
    func pdfHasOnePagePerScanPage() async throws {
        let scan = TestData.scan(title: "Two Pages", pages: [TestData.page(order: 0, text: "One"), TestData.page(order: 1, text: "Two")])
        #expect(try await export(scan, mode: .imageOnly).pageCount == 2)
    }

    @Test
    func imageOnlyPDFHasNoText() async throws {
        let scan = TestData.scan(title: "Plain", pages: [TestData.page(order: 0, text: "Hidden OCR text")])
        let document = try await export(scan, mode: .imageOnly)
        #expect((document.string ?? "").contains("Hidden OCR text") == false)
    }

    @Test
    func searchablePDFContainsEachLineExactlyOnce() async throws {
        let page = TestData.page(order: 0, text: "Aligned Text\nSecond Line", observations: [
            TestData.observation("Aligned Text", y: 0.6),
            TestData.observation("Second Line", y: 0.4)
        ])
        let document = try await export(TestData.scan(title: "Geometry", pages: [page]))

        #expect(occurrences(of: "Aligned Text", in: document) == 1)
        #expect(occurrences(of: "Second Line", in: document) == 1)
    }

    @Test
    func searchablePDFPlacesTextInsideItsBox() async throws {
        let page = TestData.page(order: 0, text: "Placed", observations: [
            TestData.observation("Placed", x: 0.5, y: 0.5, width: 0.3, height: 0.05)
        ])
        let document = try await export(TestData.scan(title: "Placement", pages: [page]), pageSize: .fitToImage)
        let pdfPage = try #require(document.page(at: 0))
        let selection = try #require(document.findString("Placed", withOptions: []).first)
        let bounds = selection.bounds(for: pdfPage)
        let pageBounds = pdfPage.bounds(for: .mediaBox)

        // Box starts at 50% of the width and 50% of the height (bottom-left origin).
        #expect(abs(bounds.minX / pageBounds.width - 0.5) < 0.05)
        #expect(abs(bounds.minY / pageBounds.height - 0.5) < 0.05)
    }

    @Test
    func editedTextIsExportedInsteadOfStaleLayout() async throws {
        let page = TestData.page(order: 0, text: "Corrected total", observations: [TestData.observation("Correctd totl")])
        let document = try await export(TestData.scan(title: "Edited", pages: [page]))

        #expect(occurrences(of: "Corrected total", in: document) == 1)
        #expect(occurrences(of: "Correctd totl", in: document) == 0)
    }

    @Test
    func pageSizesFollowSettings() async throws {
        let scan = TestData.scan(title: "Sizes", pages: [TestData.page(order: 0, text: "")]) // 600 x 900 image

        let a4 = try #require(try await export(scan, pageSize: .a4).page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(a4.width - 595.28) < 1 && abs(a4.height - 841.89) < 1)

        let letter = try #require(try await export(scan, pageSize: .letter).page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(letter.width - 612) < 1 && abs(letter.height - 792) < 1)

        let fit = try #require(try await export(scan, pageSize: .fitToImage).page(at: 0)).bounds(for: .mediaBox)
        #expect(abs(fit.width / fit.height - 600.0 / 900.0) < 0.01)
    }

    @Test
    func landscapeImagesGetLandscapePaper() {
        let layout = PDFExportService.layout(imageSize: CGSize(width: 1200, height: 800), pageSize: .a4)
        #expect(layout.page.width > layout.page.height)
        #expect(layout.image.width <= layout.page.width && layout.image.height <= layout.page.height)
    }

    @Test
    func textExportPreservesPageOrder() async throws {
        let scan = TestData.scan(title: "Text", pages: [
            TestData.page(order: 1, text: "Second page text"),
            TestData.page(order: 0, text: "First page text")
        ])
        let file = try await exporter.exportText(scan: scan)
        #expect(try String(contentsOf: file.url, encoding: .utf8) == "First page text\n\nSecond page text")
    }

    @Test
    func exportsWithTheSameTitleDoNotCollide() async throws {
        let scan = TestData.scan(title: "Same / Name", pages: [TestData.page(order: 0, text: "")])
        let first = try await exporter.exportText(scan: scan)
        let second = try await exporter.exportText(scan: scan)
        #expect(first.url != second.url)
        #expect(second.filename == "Same - Name.txt")
        // Earlier exports are cleaned up.
        #expect(!FileManager.default.fileExists(atPath: first.url.path))
    }
}
