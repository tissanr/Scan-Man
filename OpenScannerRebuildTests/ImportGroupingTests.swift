import XCTest
import UIKit
import Testing
@testable import OpenScannerRebuild

@MainActor
struct ImportGroupingTests {
    
    @Test
    func multipleImagesFromSameSourceAreGroupedIntoOneScan() async throws {
        // Arrange
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        var inbox = StubImportInbox()
        
        let url1 = createTestFile(name: "img1.jpg")
        let url2 = createTestFile(name: "img2.jpg")
        
        inbox.mockPendingImports = [
            PendingImportItem(url: url1, kind: .image, source: .shareExtension),
            PendingImportItem(url: url2, kind: .image, source: .shareExtension)
        ]
        
        let viewModel = HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            ocrProcessor: StubOCRProcessor(result: ScanOCRProcessingResult(scan: TestData.scan(title: "Mock", pages: []), failedPageCount: 0)),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: importer,
            importInbox: inbox
        )
        
        // Act
        await viewModel.load()
        
        // Assert
        #expect(repository.saveCalls.count == 1)
        #expect(importer.imagesInput.count == 1)
        #expect(importer.imagesInput.first?.count == 2)
        
        // Cleanup
        try? FileManager.default.removeItem(at: url1)
        try? FileManager.default.removeItem(at: url2)
    }
    
    @Test
    func imagesFromDifferentSourcesAreNotGrouped() async throws {
        // Arrange
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        var inbox = StubImportInbox()
        
        let url1 = createTestFile(name: "img1.jpg")
        let url2 = createTestFile(name: "img2.jpg")
        
        inbox.mockPendingImports = [
            PendingImportItem(url: url1, kind: .image, source: .shareExtension),
            PendingImportItem(url: url2, kind: .image, source: .visibleFolder)
        ]
        
        let viewModel = HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            ocrProcessor: StubOCRProcessor(result: ScanOCRProcessingResult(scan: TestData.scan(title: "Mock", pages: []), failedPageCount: 0)),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: importer,
            importInbox: inbox
        )
        
        // Act
        await viewModel.load()
        
        // Assert
        #expect(repository.saveCalls.count == 2)
        #expect(importer.imagesInput.count == 2)
        
        // Cleanup
        try? FileManager.default.removeItem(at: url1)
        try? FileManager.default.removeItem(at: url2)
    }

    @Test
    func pdfsAreAlwaysSeparateScans() async throws {
        // Arrange
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        var inbox = StubImportInbox()
        
        let url1 = createTestFile(name: "doc1.pdf")
        let url2 = createTestFile(name: "doc2.pdf")
        
        inbox.mockPendingImports = [
            PendingImportItem(url: url1, kind: .pdf, source: .shareExtension),
            PendingImportItem(url: url2, kind: .pdf, source: .shareExtension)
        ]
        
        let viewModel = HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            ocrProcessor: StubOCRProcessor(result: ScanOCRProcessingResult(scan: TestData.scan(title: "Mock", pages: []), failedPageCount: 0)),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: importer,
            importInbox: inbox
        )
        
        // Act
        await viewModel.load()
        
        // Assert
        #expect(repository.saveCalls.count == 2)
        #expect(importer.pdfInput.count == 2)
        
        // Cleanup
        try? FileManager.default.removeItem(at: url1)
        try? FileManager.default.removeItem(at: url2)
    }

    private func createTestFile(name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        // Need real image data for UIImage(data:) to work in importGroupedImageItems
        let image = UIImage(systemName: "photo")!
        let data = image.jpegData(compressionQuality: 0.8)!
        try? data.write(to: url)
        return url
    }
}
