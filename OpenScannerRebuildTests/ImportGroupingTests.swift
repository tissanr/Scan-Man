import Foundation
import Testing
import UIKit
@testable import OpenScannerRebuild

@MainActor
struct ImportGroupingTests {
    /// Per-test directory so parallel tests never share or delete each other's files.
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImportGroupingTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @Test
    func multipleImagesFromSameSourceAreGroupedIntoOneScan() async throws {
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        let inbox = StubImportInbox(mockPendingImports: [
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .shareExtension),
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .shareExtension)
        ])

        await makeViewModel(repository: repository, importer: importer, inbox: inbox).load()

        #expect(importer.imagesInput.count == 1)
        #expect(importer.imagesInput.first?.count == 2)
        #expect(savedScanIDs(in: repository).count == 1)
        #expect(inbox.removedItems.count == 2)
        cleanUp()
    }

    @Test
    func imagesFromDifferentSourcesAreNotGrouped() async throws {
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        let inbox = StubImportInbox(mockPendingImports: [
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .shareExtension),
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .visibleFolder)
        ])

        await makeViewModel(repository: repository, importer: importer, inbox: inbox).load()

        #expect(importer.imagesInput.count == 2)
        #expect(importer.imagesInput.allSatisfy { $0.count == 1 })
        #expect(savedScanIDs(in: repository).count == 2)
        #expect(inbox.removedItems.count == 2)
        cleanUp()
    }

    @Test
    func pdfsAreAlwaysSeparateScans() async throws {
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        let inbox = StubImportInbox(mockPendingImports: [
            PendingImportItem(url: try makeFile(extension: "pdf"), kind: .pdf, source: .shareExtension),
            PendingImportItem(url: try makeFile(extension: "pdf"), kind: .pdf, source: .shareExtension)
        ])

        await makeViewModel(repository: repository, importer: importer, inbox: inbox).load()

        #expect(importer.pdfInput.count == 2)
        #expect(savedScanIDs(in: repository).count == 2)
        #expect(inbox.removedItems.count == 2)
        cleanUp()
    }

    @Test
    func unreadableImagesStayInInbox() async throws {
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        let goodItem = PendingImportItem(url: try makeImageFile(), kind: .image, source: .visibleFolder)
        let badItem = PendingImportItem(url: try makeFile(extension: "jpg", data: Data("not an image".utf8)), kind: .image, source: .visibleFolder)
        let inbox = StubImportInbox(mockPendingImports: [goodItem, badItem])

        await makeViewModel(repository: repository, importer: importer, inbox: inbox).load()

        #expect(importer.imagesInput.first?.count == 1)
        #expect(inbox.removedItems == [goodItem])
        cleanUp()
    }

    // MARK: - Helpers

    private func makeViewModel(
        repository: StubScanRepository,
        importer: StubScanImporter,
        inbox: StubImportInbox
    ) -> HomeViewModel {
        HomeViewModel(
            repository: repository,
            titleSuggester: TitleSuggestionService(),
            // Echo the input scan so background OCR saves keep the same scan ID.
            ocrProcessor: StubOCRProcessor(),
            scanDeviceSupport: StubDeviceSupport(canScanDocuments: true),
            scanImporter: importer,
            importInbox: inbox
        )
    }

    /// Background OCR tasks may re-save a scan, so count distinct scans rather than save calls.
    private func savedScanIDs(in repository: StubScanRepository) -> Set<UUID> {
        Set(repository.saveCalls.map(\.id))
    }

    private func makeImageFile() throws -> URL {
        let size = CGSize(width: 40, height: 40)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let data = try #require(image.jpegData(compressionQuality: 0.8))
        return try makeFile(extension: "jpg", data: data)
    }

    private func makeFile(extension pathExtension: String, data: Data = Data("test".utf8)) throws -> URL {
        let url = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
        try data.write(to: url)
        return url
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
