import Foundation
import Testing
@testable import OpenScannerRebuild

@MainActor
struct CoreDataRepositoryTests {
    @Test
    func repositoryPreservesPageOrderingAndNormalizesStoredText() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataScanRepository(persistenceController: persistence)
        let scan = TestData.scan(title: "Receipt", pages: [
            TestData.page(order: 2, text: "  Last page "),
            TestData.page(order: 0, text: " First page \n"),
            TestData.page(order: 1, text: "Middle\n\npage")
        ])

        try await repository.save(scan: scan)
        let saved = try await repository.fetchScans()
        let loaded = try #require(saved.first)

        #expect(loaded.pages.map(\.order) == [0, 1, 2])
        #expect(loaded.pages.map(\.recognizedText) == ["First page", "Middle\npage", "Last page"])
    }

    @Test
    func repositoryCanFetchSingleScanByIdentifier() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataScanRepository(persistenceController: persistence)
        let scan = TestData.scan(title: "Single", pages: [TestData.page(order: 0, text: "Hello")])

        try await repository.save(scan: scan)
        let loaded = try await repository.fetchScan(id: scan.id)

        #expect(loaded?.id == scan.id)
        #expect(loaded?.pages.first?.recognizedText == "Hello")
    }

    @Test
    func repositoryPersistsOCRGeometry() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataScanRepository(persistenceController: persistence)
        var page = TestData.page(order: 0, text: "Hello")
        page.textObservations = [
            OCRTextObservation(
                text: "Hello",
                boundingBox: OCRBoundingBox(x: 0.1, y: 0.2, width: 0.3, height: 0.1)
            )
        ]
        let scan = TestData.scan(title: "Geometry", pages: [page])

        try await repository.save(scan: scan)
        let loaded = try await repository.fetchScan(id: scan.id)

        #expect(loaded?.pages.first?.textObservations.count == 1)
        #expect(loaded?.pages.first?.textObservations.first?.text == "Hello")
    }

    @Test
    func repositoryUpdatesRecognizedTextForSpecificPage() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataScanRepository(persistenceController: persistence)
        let firstPage = TestData.page(order: 0, text: "Before")
        let secondPage = TestData.page(order: 1, text: "Untouched")
        let scan = TestData.scan(title: "Editable", pages: [firstPage, secondPage])

        try await repository.save(scan: scan)
        try await repository.updateRecognizedText(scanID: scan.id, pageID: firstPage.id, text: "  After \n\n Edit ")
        let loaded = try await repository.fetchScan(id: scan.id)

        #expect(loaded?.pages.first?.recognizedText == "After\nEdit")
        #expect(loaded?.pages.last?.recognizedText == "Untouched")
    }
}
