import Foundation
import PDFKit
import Testing
import UIKit
@testable import OpenScannerRebuild

@MainActor
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
    func searchBehaviorMatchesTitleAndOCRText() async {
        let repository = StubScanRepository(scans: [
            TestData.scan(title: "Tax Receipt", notes: "Filed under 2026", pages: [TestData.page(order: 0, text: "Coffee beans")]),
            TestData.scan(title: "Meeting Notes", pages: [TestData.page(order: 0, text: "Quarterly planning")])
        ])
        let viewModel = HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            ocrProcessor: StubOCRProcessor(result: ScanOCRProcessingResult(scan: TestData.scan(title: "Imported", pages: []), failedPageCount: 0)),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: StubScanImporter(result: .success(TestData.scan(title: "Imported", pages: []))),
            importInbox: StubImportInbox()
        )

        await viewModel.load()
        viewModel.searchText = "coffee"

        #expect(viewModel.filteredScans.count == 1)
        #expect(viewModel.filteredScans.first?.title == "Tax Receipt")
    }

    @Test
    func searchBehaviorMatchesNotes() async {
        let repository = StubScanRepository(scans: [
            TestData.scan(title: "Receipt", notes: "Reimburse on Friday", pages: [TestData.page(order: 0, text: "Coffee beans")]),
            TestData.scan(title: "Meeting Notes", pages: [TestData.page(order: 0, text: "Quarterly planning")])
        ])
        let viewModel = HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            ocrProcessor: StubOCRProcessor(result: ScanOCRProcessingResult(scan: TestData.scan(title: "Imported", pages: []), failedPageCount: 0)),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: StubScanImporter(result: .success(TestData.scan(title: "Imported", pages: []))),
            importInbox: StubImportInbox()
        )

        await viewModel.load()
        viewModel.searchText = "reimburse"

        #expect(viewModel.filteredScans.count == 1)
        #expect(viewModel.filteredScans.first?.title == "Receipt")
    }

    @Test
    func pageEditingUpdatesPersistedSearchableText() async {
        let editablePage = TestData.page(order: 0, text: "Initial text")
        let scan = TestData.scan(title: "Editable Scan", pages: [editablePage])
        let repository = StubScanRepository(scans: [scan])
        let viewModel = ScanDetailViewModel(
            scan: scan,
            repository: repository,
            pdfExporter: PDFExportService()
        )

        let didSave = await viewModel.updateRecognizedText(for: editablePage.id, text: "  Updated invoice total  ")

        #expect(didSave)
        #expect(viewModel.scan.pages.first?.recognizedText == "Updated invoice total")
        #expect(viewModel.scan.searchText.contains("updated invoice total"))
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

    @Test
    func pdfImportCreatesPagesThatMatchTheExistingScanModel() throws {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 400))
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            NSString(string: "Page One").draw(at: CGPoint(x: 24, y: 24), withAttributes: [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ])

            context.beginPage()
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 400))
            NSString(string: "Page Two").draw(at: CGPoint(x: 24, y: 24), withAttributes: [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ])
        }

        let service = ScanImportService()
        let scan = try service.makeScanDocument(fromPDFData: pdfData, createdAt: Date(timeIntervalSince1970: 0))

        #expect(scan.pages.map(\.order) == [0, 1])
        #expect(scan.pages.allSatisfy { !$0.imageData.isEmpty })
        #expect(scan.pages.allSatisfy { !$0.thumbnailData.isEmpty })
    }

    @Test
    func ocrProcessorMapsRecognizedTextIntoStoredPagesAndSuggestsTitle() async {
        let firstPage = TestData.page(order: 0, text: "")
        let secondPage = TestData.page(order: 1, text: "")
        let recognizer = StubOCRRecognizer(
            contentByPayload: [
                firstPage.imageData: OCRPageContent(
                    text: "Invoice 42\nTotal due",
                    observations: [
                        OCRTextObservation(
                            text: "Invoice 42",
                            boundingBox: OCRBoundingBox(x: 0.1, y: 0.7, width: 0.3, height: 0.08)
                        )
                    ]
                ),
                secondPage.imageData: OCRPageContent(
                    text: "Second page body",
                    observations: [
                        OCRTextObservation(
                            text: "Second page body",
                            boundingBox: OCRBoundingBox(x: 0.15, y: 0.4, width: 0.5, height: 0.06)
                        )
                    ]
                )
            ],
            failingPayloads: []
        )
        let processor = ScanOCRProcessor(recognizer: recognizer, titleSuggester: TitleSuggestionService())

        let result = await processor.process(scan: TestData.scan(title: "Scan Jan 1", pages: [secondPage, firstPage]))

        #expect(result.failedPageCount == 0)
        #expect(result.scan.pages.map(\.recognizedText) == ["Invoice 42\nTotal due", "Second page body"])
        #expect(result.scan.pages[0].textObservations.count == 1)
        #expect(result.scan.title == "Invoice 42")
    }

    @Test
    func searchablePDFEmbedsAlignedObservationTextExactlyOnce() throws {
        let service = PDFExportService()
        var page = TestData.page(order: 0, text: "Aligned Text")
        page.textObservations = [
            OCRTextObservation(
                text: "Aligned Text",
                boundingBox: OCRBoundingBox(x: 0.2, y: 0.6, width: 0.35, height: 0.08)
            )
        ]
        let scan = TestData.scan(title: "Geometry", pages: [page])

        let exported = try service.export(scan: scan, mode: .searchable)
        let document = try #require(PDFDocument(url: exported.url))
        let pdfPage = try #require(document.page(at: 0))

        let matches = document.findString("Aligned Text", withOptions: [])
        #expect(matches.count == 1)

        // The 600x900 test image is fitted into the 564x744 content box of a 612x792 page,
        // giving a drawn image 496pt wide starting at x = 58.
        let bounds = try #require(matches.first).bounds(for: pdfPage)
        #expect(abs(bounds.minX - (58 + 496 * 0.2)) < 4)
        #expect(abs(bounds.width - 496 * 0.35) < 10)
    }

    @Test
    func searchablePDFPrefersEditedTextOverStaleGeometry() throws {
        let service = PDFExportService()
        var page = TestData.page(order: 0, text: "Edited text")
        page.textObservations = [
            OCRTextObservation(
                text: "Original OCR",
                boundingBox: OCRBoundingBox(x: 0.2, y: 0.6, width: 0.35, height: 0.08)
            )
        ]
        let scan = TestData.scan(title: "Edited", pages: [page])

        let exported = try service.export(scan: scan, mode: .searchable)
        let document = try #require(PDFDocument(url: exported.url))

        #expect(document.findString("Edited text", withOptions: []).count == 1)
        #expect(document.string?.contains("Original OCR") == false)
    }

    @Test
    func imageOnlyPDFContainsNoText() throws {
        let service = PDFExportService()
        let scan = TestData.scan(title: "Plain", pages: [TestData.page(order: 0, text: "Should not appear")])

        let exported = try service.export(scan: scan, mode: .imageOnly)
        let document = try #require(PDFDocument(url: exported.url))

        #expect(document.string?.contains("Should not appear") != true)
    }

    @Test
    func ocrResultKeepsTitleAndNotesEditedWhileProcessing() async throws {
        let original = TestData.scan(title: "Scan Jan 1", pages: [TestData.page(order: 0, text: "")])
        var ocrScan = original
        ocrScan.title = "Invoice 42"
        ocrScan.pages[0].recognizedText = "Invoice 42"

        var renamed = original
        renamed.title = "My Tax Docs"
        renamed.notes = "Keep for 10 years"
        let repository = StubScanRepository(scans: [renamed])
        let viewModel = makeHomeViewModel(repository: repository, ocrResult: ocrScan)

        await viewModel.processOCR(for: original)

        let saved = try #require(repository.savedScans.last)
        #expect(saved.title == "My Tax Docs")
        #expect(saved.notes == "Keep for 10 years")
        #expect(saved.pages.first?.recognizedText == "Invoice 42")
    }

    @Test
    func ocrResultAppliesSuggestedTitleWhenUserDidNotRename() async throws {
        let original = TestData.scan(title: "Scan Jan 1", pages: [TestData.page(order: 0, text: "")])
        var ocrScan = original
        ocrScan.title = "Invoice 42"
        let repository = StubScanRepository(scans: [original])
        let viewModel = makeHomeViewModel(repository: repository, ocrResult: ocrScan)

        await viewModel.processOCR(for: original)

        #expect(try #require(repository.savedScans.last).title == "Invoice 42")
    }

    @Test
    func ocrResultDoesNotResurrectScanDeletedWhileProcessing() async {
        let original = TestData.scan(title: "Scan Jan 1", pages: [TestData.page(order: 0, text: "")])
        let repository = StubScanRepository(scans: [])
        let viewModel = makeHomeViewModel(repository: repository, ocrResult: original)

        await viewModel.processOCR(for: original)

        #expect(repository.savedScans.isEmpty)
        #expect(repository.storedScans.isEmpty)
    }

    @Test
    func renamingTrimsTitleAndNotifiesLibrary() async {
        let scan = TestData.scan(title: "Old", pages: [TestData.page(order: 0, text: "Body")])
        let repository = StubScanRepository(scans: [scan])
        var notified: [ScanDocument] = []
        let viewModel = ScanDetailViewModel(
            scan: scan,
            repository: repository,
            pdfExporter: PDFExportService(),
            onScanUpdated: { notified.append($0) }
        )

        viewModel.title = "  New Title  "
        await viewModel.saveTitle()

        #expect(viewModel.title == "New Title")
        #expect(repository.storedScans.first?.title == "New Title")
        #expect(notified.map(\.title) == ["New Title"])
    }

    @Test
    func blankTitleRevertsToLastSavedTitle() async {
        let scan = TestData.scan(title: "Keep Me", pages: [TestData.page(order: 0, text: "Body")])
        let repository = StubScanRepository(scans: [scan])
        let viewModel = ScanDetailViewModel(scan: scan, repository: repository, pdfExporter: PDFExportService())

        viewModel.title = "   "
        await viewModel.saveTitle()

        #expect(viewModel.title == "Keep Me")
        #expect(repository.storedScans.first?.title == "Keep Me")
    }

    @Test
    func libraryReflectsEditsMadeInDetail() async {
        let scan = TestData.scan(title: "Before", pages: [TestData.page(order: 0, text: "Body")])
        let viewModel = makeHomeViewModel(repository: StubScanRepository(scans: [scan]), ocrResult: scan)
        await viewModel.load()

        var edited = scan
        edited.title = "After"
        viewModel.applyUpdatedScan(edited)

        #expect(viewModel.scans.map(\.title) == ["After"])
    }

    private func makeHomeViewModel(repository: StubScanRepository, ocrResult: ScanDocument) -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            ocrProcessor: StubOCRProcessor(result: ScanOCRProcessingResult(scan: ocrResult, failedPageCount: 0)),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: StubScanImporter(result: .success(ocrResult)),
            importInbox: StubImportInbox()
        )
    }
}
