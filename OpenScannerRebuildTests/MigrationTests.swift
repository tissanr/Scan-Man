import CoreData
import CoreGraphics
import Foundation
import UIKit
import Testing
@testable import OpenScannerRebuild

/// Verifies that a store written by the version 1 model opens with the current model without data loss.
@MainActor
struct MigrationTests {
    private static var compiledModelDirectory: URL {
        get throws {
            try #require(Bundle(for: PersistenceController.self).url(forResource: PersistenceController.modelName, withExtension: "momd"))
        }
    }

    private func model(named name: String) throws -> NSManagedObjectModel {
        let url = try Self.compiledModelDirectory.appendingPathComponent("\(name).mom")
        return try #require(NSManagedObjectModel(contentsOf: url))
    }

    @Test
    func bundleContainsBothModelVersions() throws {
        let v1 = try model(named: "OpenScannerRebuild")
        let v2 = try model(named: "OpenScannerRebuild 2")
        #expect(v1.entityVersionHashesByName != v2.entityVersionHashesByName)
        #expect(v2.entitiesByName["ScanEntity"]?.attributesByName["searchText"] != nil)
        #expect(PersistenceController.sharedModel?.entityVersionHashesByName == v2.entityVersionHashesByName)
    }

    @Test
    func version1StoreMigratesAndBackfillsSummaries() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Legacy.sqlite")

        // 1. Write a store with the version 1 model.
        let scanID = UUID()
        let pageIDs = [UUID(), UUID()]
        let imageData = TestData.jpegData(label: "Legacy")
        let layout = try JSONEncoder().encode([TestData.observation("Legacy invoice")])
        do {
            let v1 = try model(named: "OpenScannerRebuild")
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1)
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil)
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            let scan = NSManagedObject(entity: try #require(v1.entitiesByName["ScanEntity"]), insertInto: context)
            scan.setValue(scanID, forKey: "id")
            scan.setValue(Date(timeIntervalSince1970: 1_000), forKey: "createdAt")
            scan.setValue(Date(timeIntervalSince1970: 2_000), forKey: "updatedAt")
            scan.setValue("Legacy Scan", forKey: "title")
            scan.setValue("Old notes", forKey: "notes")

            for (index, pageID) in pageIDs.enumerated() {
                let page = NSManagedObject(entity: try #require(v1.entitiesByName["ScanPageEntity"]), insertInto: context)
                page.setValue(pageID, forKey: "id")
                page.setValue(Int32(index), forKey: "order")
                page.setValue(Date(timeIntervalSince1970: 1_000), forKey: "createdAt")
                page.setValue(imageData, forKey: "imageData")
                page.setValue(Data([1, 2, 3]), forKey: "thumbnailData")
                page.setValue(index == 0 ? "Legacy invoice" : "Second page", forKey: "recognizedText")
                page.setValue(index == 0 ? layout : nil, forKey: "ocrLayoutData")
                page.setValue(scan, forKey: "scan")
            }
            try context.save()
            for store in coordinator.persistentStores {
                try coordinator.remove(store)
            }
        }

        // 2. Open it with the current stack.
        let persistence = PersistenceController(storeURL: storeURL)
        #expect(persistence.loadError == nil)
        let repository = CoreDataScanRepository(persistenceController: persistence)

        // 3. Existing data is intact and new fields have defaults.
        let scan = try #require(try await repository.fetchScan(id: scanID))
        #expect(scan.title == "Legacy Scan")
        #expect(scan.notes == "Old notes")
        #expect(scan.orderedPages.map(\.id) == pageIDs)
        #expect(scan.orderedPages.map(\.recognizedText) == ["Legacy invoice", "Second page"])
        #expect(scan.orderedPages[0].textObservations == [TestData.observation("Legacy invoice")])
        #expect(scan.orderedPages[0].imageData == imageData)
        #expect(scan.orderedPages.allSatisfy { $0.enhancement == .original && $0.processedImageData == nil })

        // 4. Summary fields are rebuilt once.
        #expect(try await repository.rebuildDerivedFieldsIfNeeded() == 1)
        #expect(try await repository.rebuildDerivedFieldsIfNeeded() == 0)
        let summary = try #require(try await repository.fetchSummaries().first)
        #expect(summary.pageCount == 2)
        #expect(summary.previewText == "Legacy invoice")
        #expect(summary.thumbnailData == Data([1, 2, 3]))
        #expect(summary.matches("second page"))
        #expect(summary.matches("old notes"))
    }
}
