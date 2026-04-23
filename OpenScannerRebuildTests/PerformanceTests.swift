import XCTest
import Testing
@testable import OpenScannerRebuild

final class PerformanceTests: XCTestCase {
    
    // Using XCTest for performance benchmarks as Swift Testing doesn't natively support metrics yet
    
    func testCoreDataFetchPerformance() {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataScanRepository(persistenceController: persistence)
        
        measure {
            let expectation = expectation(description: "Fetch")
            Task {
                _ = try? await repository.fetchScans()
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPDFExportPerformance() {
        let exporter = PDFExportService()
        let scan = TestData.scan(title: "Perf Test", pages: [
            TestData.page(order: 0, text: "Page 1"),
            TestData.page(order: 1, text: "Page 2")
        ])
        
        measure {
            let expectation = expectation(description: "Export")
            Task {
                _ = try? await exporter.exportAsSearchablePDF(scan: scan)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }
}
