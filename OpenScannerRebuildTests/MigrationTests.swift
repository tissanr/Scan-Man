import XCTest
import CoreData
@testable import OpenScannerRebuild

final class MigrationTests: XCTestCase {
    
    func testMigrationInfrastructure() throws {
        // This is a placeholder for actual migration tests when a version 2 of the model is created.
        // It verifies that the current model can be loaded into an in-memory coordinator.
        
        let modelURL = Bundle.main.url(forResource: "OpenScannerRebuild", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        
        XCTAssertEqual(coordinator.managedObjectModel.entities.count, 2)
        XCTAssertTrue(coordinator.managedObjectModel.entitiesByName.keys.contains("ScanEntity"))
        XCTAssertTrue(coordinator.managedObjectModel.entitiesByName.keys.contains("ScanPageEntity"))
    }
}
