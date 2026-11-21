import Foundation
import Testing
@testable import OpenScannerRebuild

@MainActor
struct ScanDomainTests {
    @Test
    func previewTextUsesFirstNonEmptyPageInOrder() {
        let pages = [
            TestData.page(order: 1, text: "Second line"),
            TestData.page(order: 0, text: "   "),
            TestData.page(order: 2, text: "Third")
        ]
        #expect(pages.previewText == "Second line")
    }

    @Test
    func titleSuggestionSkipsLinesWithoutWords() {
        let title = TitleSuggestionService().suggestTitle(for: ["12/03/2026\n#42\nInvoice 1024\nTotal"])
        #expect(title == "Invoice 1024")
    }

    @Test
    func titleSuggestionReturnsNilWithoutText() {
        #expect(TitleSuggestionService().suggestTitle(for: ["", "  \n 123 "]) == nil)
    }

    @Test
    func placeholderTitlesAreOnlyAppGeneratedOnes() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(ScanDefaults.isPlaceholderTitle("", createdAt: date))
        #expect(ScanDefaults.isPlaceholderTitle(ScanDefaults.untitledTitle, createdAt: date))
        #expect(ScanDefaults.isPlaceholderTitle(ScanDefaults.defaultTitle(for: date), createdAt: date))
        // A real title that happens to start with "Scan " must never be replaced.
        #expect(!ScanDefaults.isPlaceholderTitle("Scan of passport", createdAt: date))
        #expect(!ScanDefaults.isPlaceholderTitle("Tax return", createdAt: date))
    }

    @Test
    func summarySearchIsCaseAndDiacriticInsensitive() {
        let scan = TestData.scan(title: "Café receipt", notes: "Paid in cash", pages: [TestData.page(order: 0, text: "Total 12 EUR")])
        let summary = ScanSummary(scan: scan)
        #expect(summary.matches("cafe"))
        #expect(summary.matches("PAID"))
        #expect(summary.matches("total 12"))
        #expect(!summary.matches("invoice"))
        #expect(summary.matches("   "))
    }

    @Test
    func textMatchesLayoutDetectsEditedText() {
        var page = TestData.page(order: 0, text: "Hello\nWorld", observations: [
            TestData.observation("World", y: 0.4),
            TestData.observation("Hello", y: 0.6)
        ])
        #expect(page.textMatchesLayout)
        page.recognizedText = "Hello\nEdited"
        #expect(!page.textMatchesLayout)
    }

    @Test
    func orderedObservationsFollowReadingOrder() {
        let page = TestData.page(order: 0, text: "", observations: [
            TestData.observation("Bottom", x: 0.1, y: 0.1),
            TestData.observation("Top right", x: 0.6, y: 0.8),
            TestData.observation("Top left", x: 0.1, y: 0.8)
        ])
        #expect(page.orderedTextObservations.map(\.text) == ["Top left", "Top right", "Bottom"])
    }

    @Test
    func displayImagePrefersProcessedImage() {
        var page = TestData.page(order: 0, text: "")
        #expect(page.displayImageData == page.imageData)
        page.processedImageData = Data([1, 2, 3])
        #expect(page.displayImageData == Data([1, 2, 3]))
    }

    @Test
    func exportFilenamesAreSanitized() {
        #expect(ExportDirectory.sanitizedFilename("Invoice 3/2026: Final?") == "Invoice 3-2026- Final-")
        #expect(ExportDirectory.sanitizedFilename("  ") == "Scan Man Export")
        #expect(ExportDirectory.sanitizedFilename("...") == "Scan Man Export")
    }

    @Test
    func regionDefaultPageSize() {
        #expect(PDFPageSize.regionDefault(for: Locale(identifier: "en_US")) == .letter)
        #expect(PDFPageSize.regionDefault(for: Locale(identifier: "de_DE")) == .a4)
    }

    @Test
    func settingsPersistAcrossInstances() {
        let defaults = TestData.isolatedDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.defaultEnhancement = .blackAndWhite
        settings.pdfPageSize = .letter
        settings.imageQuality = .small
        settings.hasCompletedOnboarding = true

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.defaultEnhancement == .blackAndWhite)
        #expect(reloaded.pdfPageSize == .letter)
        #expect(reloaded.imageQuality == .small)
        #expect(reloaded.hasCompletedOnboarding)
        #expect(!reloaded.appLockEnabled)
    }
}
