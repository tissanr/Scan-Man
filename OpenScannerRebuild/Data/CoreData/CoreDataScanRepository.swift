import CoreData
import Foundation

struct CoreDataScanRepository: ScanRepository {
    let persistenceController: PersistenceController

    func fetchScans() async throws -> [ScanDocument] {
        try await persistenceController.performBackgroundTask { context in
            let request = ScanEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).map { $0.toDomainModel() }
        }
    }

    func fetchScan(id: UUID) async throws -> ScanDocument? {
        try await persistenceController.performBackgroundTask { context in
            let request = ScanEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            return try context.fetch(request).first?.toDomainModel()
        }
    }

    func save(scan: ScanDocument) async throws {
        _ = try await persistenceController.performBackgroundTask { context in
            let request = ScanEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", scan.id as CVarArg)
            let entity = try context.fetch(request).first ?? ScanEntity(context: context)
            entity.id = scan.id
            entity.createdAt = scan.createdAt
            entity.updatedAt = scan.updatedAt
            entity.title = scan.title

            entity.orderedPages.forEach(context.delete)

            for page in scan.pages.sorted(by: { $0.order < $1.order }) {
                let pageEntity = ScanPageEntity(context: context)
                pageEntity.id = page.id
                pageEntity.order = Int32(page.order)
                pageEntity.createdAt = page.createdAt
                pageEntity.imageData = page.imageData
                pageEntity.thumbnailData = page.thumbnailData
                pageEntity.recognizedText = page.recognizedText.normalizedOCRText
                pageEntity.scan = entity
            }
        }
    }

    func updateTitle(scanID: UUID, title: String) async throws {
        _ = try await persistenceController.performBackgroundTask { context in
            let request = ScanEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", scanID as CVarArg)
            guard let entity = try context.fetch(request).first else {
                return
            }

            entity.title = title
            entity.updatedAt = Date()
        }
    }

    func delete(scanID: UUID) async throws {
        _ = try await persistenceController.performBackgroundTask { context in
            let request = ScanEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", scanID as CVarArg)
            try context.fetch(request).forEach(context.delete)
        }
    }

    func deleteAll() async throws {
        _ = try await persistenceController.performBackgroundTask { context in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ScanEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try context.execute(deleteRequest)
        }
    }
}

private extension ScanEntity {
    func toDomainModel() -> ScanDocument {
        ScanDocument(
            id: id ?? UUID(),
            createdAt: createdAt ?? .distantPast,
            updatedAt: updatedAt ?? .distantPast,
            title: title ?? "Untitled Scan",
            pages: orderedPages.map {
                ScanPage(
                    id: $0.id ?? UUID(),
                    order: Int($0.order),
                    createdAt: $0.createdAt ?? .distantPast,
                    imageData: $0.imageData ?? Data(),
                    thumbnailData: $0.thumbnailData ?? Data(),
                    recognizedText: ($0.recognizedText ?? "").normalizedOCRText
                )
            }
        )
    }
}
