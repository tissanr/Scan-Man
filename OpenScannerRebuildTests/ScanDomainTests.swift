import Foundation
import PDFKit
import Testing
import UIKit
@testable import OpenScannerRebuild

struct ScanDomainTests {
    @Test
    func textPreviewGenerationUsesNormalizedFirstNonEmptyPage() {
        let pages = [
            TestData.page(order: 1, text: "   "),
            TestData.page(order: 0, text: "First line\n\nSecond line")
        ]

        #expect(pages.previewText == "First line Second line")
    }

    @Test
    func titleSuggestionUsesFirstMeaningfulOCRLine() {
        let service = TitleSuggestionService()
        let title = service.suggestTitle(for: [
            TestData.page(order: 1, text: "Later Page"),
            TestData.page(order: 0, text: "\n  Invoice 1024 \nTotal")
        ])

        #expect(title == "Invoice 1024")
    }

    @Test
    @MainActor
    func searchBehaviorMatchesTitleAndOCRText() {
        let repository = StubScanRepository(scans: [
            TestData.scan(title: "Tax Receipt", pages: [TestData.page(order: 0, text: "Coffee beans")]),
            TestData.scan(title: "Meeting Notes", pages: [TestData.page(order: 0, text: "Quarterly planning")])
        ])
        let viewModel = HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: StubScanImporter(result: .success(TestData.scan(title: "Imported", pages: [])))
        )

        await viewModel.load()
        viewModel.searchText = "coffee"

        #expect(viewModel.filteredScans.count == 1)
        #expect(viewModel.filteredScans.first?.title == "Tax Receipt")
    }

    @Test
    func textExportContentPreservesPageOrder() throws {
        let service = PDFExportService()
        let scan = TestData.scan(title: "Export Me", pages: [
            TestData.page(order: 1, text: "Second page text"),
            TestData.page(order: 0, text: "First page text")
        ])

        let exported = try service.exportText(scan: scan)
        let content = try String(contentsOf: exported.url, encoding: .utf8)

        #expect(content == "First page text\n\nSecond page text")
    }

    @Test
    func pdfExportProducesExpectedPageCount() throws {
        let service = PDFExportService()
        let scan = TestData.scan(title: "Pages", pages: [
            TestData.page(order: 0, text: "One"),
            TestData.page(order: 1, text: "Two")
        ])

        let exported = try service.export(scan: scan, mode: .imageOnly)
        let document = try #require(PDFDocument(url: exported.url))

        #expect(document.pageCount == 2)
    }

    @Test
    func searchablePDFContainsExtractableText() throws {
        let service = PDFExportService()
        let scan = TestData.scan(title: "Searchable", pages: [
            TestData.page(order: 0, text: "Hidden OCR text")
        ])

        let exported = try service.export(scan: scan, mode: .searchable)
        let document = try #require(PDFDocument(url: exported.url))

        #expect(document.string?.contains("Hidden OCR text") == true)
    }

    @Test
    func scanImportPreservesPageOrderingAndCreatesThumbnails() throws {
        let service = ScanImportService()
        let images = [
            TestData.uiImage(label: "First"),
            TestData.uiImage(label: "Second")
        ]

        let scan = try service.makeScanDocument(from: images, createdAt: Date(timeIntervalSince1970: 0))

        #expect(scan.pages.map(\.order) == [0, 1])
        #expect(scan.pages.allSatisfy { !$0.imageData.isEmpty })
        #expect(scan.pages.allSatisfy { !$0.thumbnailData.isEmpty })
    }
}
