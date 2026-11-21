import CoreData
import Foundation
import OSLog

/// Owns the Core Data stack. All reads and writes go through `performBackgroundTask`.
nonisolated final class PersistenceController: @unchecked Sendable {
    static let modelName = "OpenScannerRebuild"

    /// Loaded once per process. Loading the model per container makes several models claim the same
    /// NSManagedObject subclasses, which Core Data cannot disambiguate.
    nonisolated(unsafe) static let sharedModel: NSManagedObjectModel? = {
        guard let url = Bundle(for: PersistenceController.self).url(forResource: modelName, withExtension: "momd") else {
            return nil
        }
        return NSManagedObjectModel(contentsOf: url)
    }()

    let container: NSPersistentContainer
    let loadError: Error?

    /// - Parameters:
    ///   - inMemory: Use a throwaway store in a unique temporary directory (for tests and previews).
    ///   - storeURL: Explicit SQLite location; overrides `inMemory`.
    init(inMemory: Bool = false, storeURL: URL? = nil) {
        let container = Self.sharedModel.map { NSPersistentContainer(name: Self.modelName, managedObjectModel: $0) }
            ?? NSPersistentContainer(name: Self.modelName)
        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()

        if let storeURL {
            description.url = storeURL
        } else if inMemory {
            // A real SQLite file (not /dev/null) so external binary storage and batch requests work.
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ScanManStore-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            description.url = directory.appendingPathComponent("\(Self.modelName).sqlite")
        }

        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        // Scans often contain sensitive documents: keep the store encrypted while the device is locked,
        // but allow an already-open store to finish background OCR writes.
        description.setOption(FileProtectionType.completeUnlessOpen as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        container.persistentStoreDescriptions = [description]

        var capturedError: Error?
        container.loadPersistentStores { _, error in
            capturedError = error
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        if let capturedError {
            Logger.persistence.fault("Failed to load persistent store: \(capturedError.localizedDescription, privacy: .public)")
        }

        self.container = container
        self.loadError = capturedError
    }

    /// Runs `work` on a fresh background context and saves it if anything changed.
    func performBackgroundTask<T: Sendable>(
        _ work: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        if let loadError {
            throw AppError.persistence(loadError.localizedDescription)
        }

        return try await container.performBackgroundTask { context in
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            let result = try work(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        }
    }
}
