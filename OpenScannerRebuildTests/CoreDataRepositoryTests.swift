import Foundation
import Testing
@testable import OpenScannerRebuild

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
}
