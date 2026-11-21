import CoreGraphics
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

    private func run(_ items: [PendingImportItem]) async -> (StubScanRepository, StubScanImporter, StubImportInbox) {
        let repository = StubScanRepository()
        let importer = StubScanImporter()
        let inbox = StubImportInbox(mockPendingImports: items)
        await TestEnvironment(repository: repository, importer: importer, inbox: inbox).makeHomeViewModel().load()
        return (repository, importer, inbox)
    }

    @Test
    func imagesFromTheSameSourceBecomeOneScan() async throws {
        let (repository, importer, inbox) = await run([
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .shareExtension),
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .shareExtension)
        ])

        #expect(importer.imagesInput.map(\.count) == [2])
        #expect(Set(repository.saveCalls.map(\.id)).count == 1)
        #expect(inbox.removedItems.count == 2)
        cleanUp()
    }

    @Test
    func imagesFromDifferentSourcesAreNotGrouped() async throws {
        let (repository, importer, inbox) = await run([
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .shareExtension),
            PendingImportItem(url: try makeImageFile(), kind: .image, source: .visibleFolder)
        ])

        #expect(importer.imagesInput.map(\.count) == [1, 1])
        #expect(Set(repository.saveCalls.map(\.id)).count == 2)
        #expect(inbox.removedItems.count == 2)
        cleanUp()
    }

    @Test
    func pdfsAreAlwaysSeparateScans() async throws {
        let (repository, importer, inbox) = await run([
            PendingImportItem(url: try makeFile(extension: "pdf"), kind: .pdf, source: .shareExtension),
            PendingImportItem(url: try makeFile(extension: "pdf"), kind: .pdf, source: .shareExtension)
        ])

        #expect(importer.pdfInput.count == 2)
        #expect(Set(repository.saveCalls.map(\.id)).count == 2)
        #expect(inbox.removedItems.count == 2)
        cleanUp()
    }

    @Test
    func unreadableImagesStayInTheInbox() async throws {
        let good = PendingImportItem(url: try makeImageFile(), kind: .image, source: .visibleFolder)
        let bad = PendingImportItem(url: try makeFile(extension: "jpg", data: Data("not an image".utf8)), kind: .image, source: .visibleFolder)
        let (_, importer, inbox) = await run([good, bad])

        #expect(importer.imagesInput.map(\.count) == [1])
        #expect(inbox.removedItems == [good])
        cleanUp()
    }

    private func makeImageFile() throws -> URL {
        try makeFile(extension: "jpg", data: TestData.jpegData(size: CGSize(width: 40, height: 40)))
    }

    private func makeFile(extension pathExtension: String, data: Data = Data("test".utf8)) throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(pathExtension)
        try data.write(to: url)
        return url
    }

    private func cleanUp() {
        try? FileManager.default.removeItem(at: directory)
    }
}
