import Foundation
import Testing
@testable import OpenScannerRebuild

@MainActor
struct CoreDataRepositoryTests {
    let repository = CoreDataScanRepository(persistenceController: PersistenceController(inMemory: true))

    @Test
    func savePreservesPageOrderingAndNormalizesText() async throws {
        let scan = TestData.scan(title: "Receipt", pages: [
            TestData.page(order: 2, text: "  Last page "),
            TestData.page(order: 0, text: " First page \n"),
            TestData.page(order: 1, text: "Middle\n\npage")
        ])

        try await repository.save(scan: scan)
        let loaded = try #require(try await repository.fetchScan(id: scan.id))

        #expect(loaded.orderedPages.map(\.order) == [0, 1, 2])
        #expect(loaded.orderedPages.map(\.recognizedText) == ["First page", "Middle\npage", "Last page"])
    }

    @Test
    func summariesCarryListFieldsWithoutPages() async throws {
        let older = TestData.scan(title: "Older", createdAt: Date(timeIntervalSinceNow: -100), pages: [TestData.page(order: 0, text: "Alpha")])
        let newer = TestData.scan(title: "Newer", notes: "Signed copy", pages: [
            TestData.page(order: 0, text: "Beta page"),
            TestData.page(order: 1, text: "Gamma")
        ])
        try await repository.save(scan: older)
        try await repository.save(scan: newer)

        let summaries = try await repository.fetchSummaries()

        #expect(summaries.map(\.title) == ["Newer", "Older"])
        let first = try #require(summaries.first)
        #expect(first.pageCount == 2)
        #expect(first.previewText == "Beta page")
        #expect(first.thumbnailData == newer.pages[0].thumbnailData)
        #expect(first.matches("gamma"))
        #expect(first.matches("signed"))
    }

    @Test
    func persistsNotesGeometryAndEnhancement() async throws {
        var page = TestData.page(order: 0, text: "Hello", observations: [TestData.observation("Hello")])
        page.enhancement = .grayscale
        page.processedImageData = Data([9, 9, 9])
        let scan = TestData.scan(title: "Geometry", notes: "Client copy", pages: [page])

        try await repository.save(scan: scan)
        let loaded = try #require(try await repository.fetchScan(id: scan.id))

        #expect(loaded.notes == "Client copy")
        #expect(loaded.pages.first?.textObservations == [TestData.observation("Hello")])
        #expect(loaded.pages.first?.enhancement == .grayscale)
        #expect(loaded.pages.first?.processedImageData == Data([9, 9, 9]))
    }

    @Test
    func targetedUpdatesChangeOnlyTheirField() async throws {
        let first = TestData.page(order: 0, text: "Before")
        let second = TestData.page(order: 1, text: "Untouched")
        let scan = TestData.scan(title: "Editable", pages: [first, second])
        try await repository.save(scan: scan)

        try await repository.updateRecognizedText(scanID: scan.id, pageID: first.id, text: "  After \n\n Edit ")
        try await repository.updateNotes(scanID: scan.id, notes: "  Shared with legal  ")
        try await repository.updateTitle(scanID: scan.id, title: "  Renamed ")

        let loaded = try #require(try await repository.fetchScan(id: scan.id))
        #expect(loaded.orderedPages.map(\.recognizedText) == ["After\nEdit", "Untouched"])
        #expect(loaded.notes == "Shared with legal")
        #expect(loaded.title == "Renamed")
        #expect(loaded.updatedAt > scan.updatedAt)

        let summary = try #require(try await repository.fetchSummaries().first)
        #expect(summary.matches("legal"))
        #expect(summary.title == "Renamed")
    }

    @Test
    func ocrResultsDoNotOverwriteUserEditsOrRealTitles() async throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let edited = TestData.page(order: 0, text: "")
        let fresh = TestData.page(order: 1, text: "")
        let scan = TestData.scan(title: ScanDefaults.defaultTitle(for: createdAt), createdAt: createdAt, pages: [edited, fresh])
        try await repository.save(scan: scan)

        // The user types text and renames the scan while OCR is running.
        try await repository.updateRecognizedText(scanID: scan.id, pageID: edited.id, text: "User text")
        try await repository.updateTitle(scanID: scan.id, title: "My title")

        try await repository.applyOCRResults(scanID: scan.id, results: [
            PageOCRResult(pageID: edited.id, text: "OCR one", observations: [TestData.observation("OCR one")]),
            PageOCRResult(pageID: fresh.id, text: "OCR two", observations: [])
        ], suggestedTitle: "Suggested")

        let loaded = try #require(try await repository.fetchScan(id: scan.id))
        #expect(loaded.orderedPages.map(\.recognizedText) == ["User text", "OCR two"])
        #expect(loaded.orderedPages[0].textObservations.count == 1)
        #expect(loaded.title == "My title")
    }

    @Test
    func ocrResultsReplacePlaceholderTitle() async throws {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let page = TestData.page(order: 0, text: "")
        let scan = TestData.scan(title: ScanDefaults.defaultTitle(for: createdAt), createdAt: createdAt, pages: [page])
        try await repository.save(scan: scan)

        try await repository.applyOCRResults(scanID: scan.id, results: [PageOCRResult(pageID: page.id, text: "Invoice", observations: [])],
                                             suggestedTitle: "Invoice")

        #expect(try await repository.fetchScan(id: scan.id)?.title == "Invoice")
    }

    @Test
    func ocrResultsForDeletedScanDoNotRecreateIt() async throws {
        let page = TestData.page(order: 0, text: "")
        let scan = TestData.scan(title: "Gone", pages: [page])
        try await repository.save(scan: scan)
        try await repository.delete(scanID: scan.id)

        try await repository.applyOCRResults(scanID: scan.id, results: [PageOCRResult(pageID: page.id, text: "Late", observations: [])],
                                             suggestedTitle: nil)

        #expect(try await repository.fetchScan(id: scan.id) == nil)
        #expect(try await repository.fetchSummaries().isEmpty)
    }

    @Test
    func pageManagementAppendsReordersAndDeletes() async throws {
        let a = TestData.page(order: 0, text: "A")
        let b = TestData.page(order: 1, text: "B")
        let scan = TestData.scan(title: "Pages", pages: [a, b])
        try await repository.save(scan: scan)

        let c = TestData.page(order: 0, text: "C")
        try await repository.appendPages(scanID: scan.id, pages: [c])
        try await repository.reorderPages(scanID: scan.id, orderedPageIDs: [c.id, a.id, b.id])
        try await repository.deletePage(scanID: scan.id, pageID: a.id)

        let loaded = try #require(try await repository.fetchScan(id: scan.id))
        #expect(loaded.orderedPages.map(\.recognizedText) == ["C", "B"])
        #expect(loaded.orderedPages.map(\.order) == [0, 1])
        #expect(try await repository.fetchSummaries().first?.pageCount == 2)
    }

    @Test
    func lastPageCannotBeDeleted() async throws {
        let page = TestData.page(order: 0, text: "Only")
        let scan = TestData.scan(title: "Single", pages: [page])
        try await repository.save(scan: scan)

        await #expect(throws: AppError.lastPageCannotBeDeleted) {
            try await repository.deletePage(scanID: scan.id, pageID: page.id)
        }
    }

    @Test
    func replacingAnImageCanResetOCR() async throws {
        let page = TestData.page(order: 0, text: "Old text", observations: [TestData.observation("Old text")])
        let scan = TestData.scan(title: "Rotate", pages: [page])
        try await repository.save(scan: scan)

        let update = PageImageUpdate(imageData: Data([1]), processedImageData: nil, enhancement: .original,
                                     thumbnailData: Data([2]), resetsOCR: true)
        try await repository.replacePageImage(scanID: scan.id, pageID: page.id, update: update)

        let loaded = try #require(try await repository.fetchScan(id: scan.id)?.pages.first)
        #expect(loaded.imageData == Data([1]))
        #expect(loaded.recognizedText.isEmpty)
        #expect(loaded.textObservations.isEmpty)
        #expect(try await repository.fetchSummaries().first?.thumbnailData == Data([2]))
    }

    @Test
    func missingScanThrowsNotFound() async {
        await #expect(throws: AppError.notFound) {
            try await repository.updateTitle(scanID: UUID(), title: "Nope")
        }
    }

    @Test
    func deleteAllRemovesEverything() async throws {
        try await repository.save(scan: TestData.scan(title: "One", pages: [TestData.page(order: 0, text: "1")]))
        try await repository.save(scan: TestData.scan(title: "Two", pages: [TestData.page(order: 0, text: "2")]))
        try await repository.deleteAll()
        #expect(try await repository.fetchSummaries().isEmpty)
    }
}
