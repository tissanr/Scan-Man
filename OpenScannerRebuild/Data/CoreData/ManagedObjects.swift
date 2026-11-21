import CoreData
import Foundation

// Hand-written managed object classes (model codegen is set to Manual/None) so their
// isolation is explicit: they are only touched inside background-context closures.

@objc(ScanEntity)
nonisolated final class ScanEntity: NSManagedObject {
    @nonobjc static func makeFetchRequest() -> NSFetchRequest<ScanEntity> {
        NSFetchRequest<ScanEntity>(entityName: "ScanEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var title: String?
    @NSManaged var notes: String?
    @NSManaged var pageCount: Int32
    @NSManaged var previewText: String?
    @NSManaged var searchText: String?
    @NSManaged var coverThumbnailData: Data?
    @NSManaged var pages: NSSet?

    /// Inserts using the context's own model, so it works even when several models are loaded (tests, migration).
    static func insert(into context: NSManagedObjectContext) -> ScanEntity {
        ScanEntity(entity: context.entityDescription(named: "ScanEntity"), insertInto: context)
    }

    var orderedPages: [ScanPageEntity] {
        let pageSet = pages as? Set<ScanPageEntity> ?? []
        return pageSet.sorted { $0.order < $1.order }
    }
}

@objc(ScanPageEntity)
nonisolated final class ScanPageEntity: NSManagedObject {
    @nonobjc static func makeFetchRequest() -> NSFetchRequest<ScanPageEntity> {
        NSFetchRequest<ScanPageEntity>(entityName: "ScanPageEntity")
    }

    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var order: Int32
    @NSManaged var imageData: Data?
    @NSManaged var processedImageData: Data?
    @NSManaged var enhancement: String?
    @NSManaged var thumbnailData: Data?
    @NSManaged var recognizedText: String?
    @NSManaged var ocrLayoutData: Data?
    @NSManaged var scan: ScanEntity?

    static func insert(into context: NSManagedObjectContext) -> ScanPageEntity {
        ScanPageEntity(entity: context.entityDescription(named: "ScanPageEntity"), insertInto: context)
    }
}

nonisolated extension NSManagedObjectContext {
    func entityDescription(named name: String) -> NSEntityDescription {
        guard let model = persistentStoreCoordinator?.managedObjectModel,
              let entity = model.entitiesByName[name] else {
            preconditionFailure("Entity \(name) missing from the Core Data model")
        }
        return entity
    }
}
