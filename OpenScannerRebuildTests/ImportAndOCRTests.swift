import Foundation
import Testing
@testable import OpenScannerRebuild

@MainActor
struct ImportAndOCRTests {
    let importer = ScanImportService(imageProcessor: CoreImageProcessor())

    @Test
    func imageImportKeepsOrderAndCreatesThumbnails() async throws {
        let scan = try await importer.makeScanDocument(
            fromImageData: [TestData.jpegData(label: "One"), TestData.jpegData(label: "Two")],
            createdAt: Date(timeIntervalSince1970: 0),
            options: .standard
        )
        #expect(scan.pages.map(\.order) == [0, 1])
        #expect(scan.pages.allSatisfy { !$0.imageData.isEmpty && !$0.thumbnailData.isEmpty })
        #expect(scan.title == ScanDefaults.defaultTitle(for: Date(timeIntervalSince1970: 0)))
    }

    @Test
    func defaultFilterIsAppliedOnImport() async throws {
        let scan = try await importer.makeScanDocument(
            fromImageData: [TestData.jpegData()],
            createdAt: Date(),
            options: ImportOptions(enhancement: .grayscale, quality: .medium)
        )
        let page = try #require(scan.pages.first)
        #expect(page.enhancement == .grayscale)
        #expect(page.processedImageData != nil)
    }

    @Test
    func pdfImportCreatesOnePagePerPDFPage() async throws {
        let pdf = TestData.pdfData(pageSizes: [CGSize(width: 300, height: 400), CGSize(width: 500, height: 300)])
        let scan = try await importer.makeScanDocument(fromPDFData: pdf, createdAt: Date(), options: .standard)

        #expect(scan.pages.map(\.order) == [0, 1])
        let second = try #require(TestData.pixelSize(of: scan.pages[1].imageData))
        #expect(second.width > second.height)
    }

    @Test
    func invalidPDFThrows() async {
        await #expect(throws: ScanImportError.invalidPDF) {
            _ = try await importer.makeScanDocument(fromPDFData: Data("not a pdf".utf8), createdAt: Date(), options: .standard)
        }
    }

    @Test
    func appendedPagesContinueNumbering() async throws {
        let pages = try await importer.makePages(fromImageData: [TestData.jpegData()], startingOrder: 3, createdAt: Date(), options: .standard)
        #expect(pages.map(\.order) == [3])
    }

    @Test
    func ocrProcessorReportsFailuresAndSuggestsTitle() async {
        let first = TestData.page(order: 0, text: "")
        let second = TestData.page(order: 1, text: "")
        let broken = ScanPage(id: UUID(), order: 2, createdAt: Date(), imageData: Data([0]), thumbnailData: Data(),
                              recognizedText: "", textObservations: [])
        let recognizer = StubOCRRecognizer(
            contentByPayload: [
                first.imageData: OCRPageContent(text: "Invoice 42\nTotal due", observations: [TestData.observation("Invoice 42")]),
                second.imageData: OCRPageContent(text: "Second page body", observations: [])
            ],
            failingPayloads: [broken.imageData]
        )
        let processor = ScanOCRProcessor(recognizer: recognizer, titleSuggester: TitleSuggestionService())

        let result = await processor.process(pages: [second, broken, first], suggestTitle: true)

        #expect(result.pageResults.map(\.pageID) == [first.id, second.id])
        #expect(result.pageResults.map(\.text) == ["Invoice 42\nTotal due", "Second page body"])
        #expect(result.failedPageIDs == [broken.id])
        #expect(result.suggestedTitle == "Invoice 42")
    }

    @Test
    func ocrRunsOnTheUnfilteredOriginal() async {
        var page = TestData.page(order: 0, text: "")
        page.processedImageData = Data([7, 7, 7])
        let recognizer = StubOCRRecognizer(contentByPayload: [page.imageData: OCRPageContent(text: "Original", observations: [])])
        let result = await ScanOCRProcessor(recognizer: recognizer, titleSuggester: TitleSuggestionService())
            .process(pages: [page], suggestTitle: false)
        #expect(result.pageResults.first?.text == "Original")
        #expect(result.suggestedTitle == nil)
    }

    @Test
    func visionRecognizesRenderedText() async throws {
        let data = TestData.jpegData(label: "HELLO SCANNER", size: CGSize(width: 800, height: 400))
        let content = try await VisionOCRService().recognizePage(in: data)
        #expect(content.text.uppercased().contains("HELLO"))
        #expect(!content.observations.isEmpty)
    }

    @Test
    func coordinatorStoresResultsAndSignalsChange() async throws {
        let page = TestData.page(order: 0, text: "")
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let scan = TestData.scan(title: ScanDefaults.defaultTitle(for: createdAt), createdAt: createdAt, pages: [page])
        let repository = StubScanRepository(scans: [scan])
        let environment = TestEnvironment(repository: repository, ocrProcessor: StubOCRProcessor(text: "Receipt", suggestedTitle: "Receipt"))

        let outcome = await environment.ocrCoordinator.recognize(scanID: scan.id, pages: scan.pages, suggestTitle: true)

        #expect(outcome == .completed)
        #expect(environment.events.revision == 1)
        #expect(!environment.ocrCoordinator.isRecognizing(scanID: scan.id))
        let stored = try #require(try await repository.fetchScan(id: scan.id))
        #expect(stored.title == "Receipt")
        #expect(stored.pages.first?.recognizedText == "Receipt")
    }
}
