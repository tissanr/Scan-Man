import CoreGraphics
import Foundation
import UIKit
import Testing
@testable import OpenScannerRebuild

/// Coarse performance budgets. They catch order-of-magnitude regressions, e.g. the library list
/// loading every page image again.
@MainActor
struct PerformanceTests {
    @Test
    func libraryListLoadsQuicklyWithManyLargeScans() async throws {
        let repository = CoreDataScanRepository(persistenceController: PersistenceController(inMemory: true))
        let largeImage = TestData.jpegData(size: CGSize(width: 2400, height: 3200))
        for index in 0..<40 {
            var pages: [ScanPage] = []
            for order in 0..<3 {
                var page = TestData.page(order: order, text: "Scan \(index) page \(order)")
                page.imageData = largeImage
                pages.append(page)
            }
            try await repository.save(scan: TestData.scan(title: "Scan \(index)", pages: pages))
        }

        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            let summaries = try await repository.fetchSummaries()
            #expect(summaries.count == 40)
        }
        #expect(elapsed < .seconds(1), "Fetching 40 summaries took \(elapsed)")
    }

    @Test
    func searchablePDFExportOfTenPagesIsFast() async throws {
        let exporter = PDFExportService(imageProcessor: CoreImageProcessor())
        let pages = (0..<10).map { TestData.page(order: $0, text: "Line \($0)", observations: [TestData.observation("Line \($0)")]) }
        let scan = TestData.scan(title: "Perf", pages: pages)

        let elapsed = try await ContinuousClock().measure {
            _ = try await exporter.export(scan: scan, mode: .searchable, options: .standard)
        }
        #expect(elapsed < .seconds(10), "Export took \(elapsed)")
    }
}
