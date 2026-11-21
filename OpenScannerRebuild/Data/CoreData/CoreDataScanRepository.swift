import CoreData
import Foundation
import OSLog

nonisolated struct CoreDataScanRepository: ScanRepository {
    let persistenceController: PersistenceController

    func fetchSummaries() async throws -> [ScanSummary] {
        try await perform { context in
            let request = ScanEntity.makeFetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            // Don't pull pages (and their images) into memory for the list.
            request.relationshipKeyPathsForPrefetching = []
            return try context.fetch(request).map { $0.toSummary() }
        }
    }

    func fetchScan(id: UUID) async throws -> ScanDocument? {
        try await perform { context in
            try Self.scanEntity(id: id, in: context)?.toDomainModel()
        }
    }

    func save(scan: ScanDocument) async throws {
        try await perform { context in
            let entity = try Self.scanEntity(id: scan.id, in: context) ?? ScanEntity.insert(into: context)
            entity.id = scan.id
            entity.createdAt = scan.createdAt
            entity.updatedAt = scan.updatedAt
            entity.title = scan.title
            entity.notes = scan.notes

            entity.orderedPages.forEach(context.delete)
            for (index, page) in scan.orderedPages.enumerated() {
                let pageEntity = ScanPageEntity.insert(into: context)
                pageEntity.apply(page, order: index)
                pageEntity.scan = entity
            }
            entity.refreshDerivedFields(pages: scan.orderedPages)
        }
    }

    func updateTitle(scanID: UUID, title: String) async throws {
        try await mutateScan(scanID) { entity, _ in
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            entity.title = trimmed.isEmpty ? ScanDefaults.untitledTitle : trimmed
        }
    }

    func updateNotes(scanID: UUID, notes: String) async throws {
        try await mutateScan(scanID) { entity, _ in
            entity.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func updateRecognizedText(scanID: UUID, pageID: UUID, text: String) async throws {
        try await mutateScan(scanID) { entity, _ in
            guard let page = entity.orderedPages.first(where: { $0.id == pageID }) else {
                throw AppError.notFound
            }
            page.recognizedText = text.normalizedOCRText
        }
    }

    func applyOCRResults(scanID: UUID, results: [PageOCRResult], suggestedTitle: String?) async throws {
        try await perform { context in
            guard let entity = try Self.scanEntity(id: scanID, in: context) else {
                Logger.persistence.info("Skipping OCR results for a scan that was deleted")
                return
            }

            let encoder = JSONEncoder()
            let pagesByID = Dictionary(entity.orderedPages.compactMap { page in page.id.map { ($0, page) } },
                                       uniquingKeysWith: { first, _ in first })
            for result in results {
                guard let page = pagesByID[result.pageID] else { continue }
                page.ocrLayoutData = try? encoder.encode(result.observations)
                // Keep text the user typed while OCR was running.
                if (page.recognizedText ?? "").isEmpty {
                    page.recognizedText = result.text.normalizedOCRText
                }
            }

            if let suggestedTitle, !suggestedTitle.isEmpty,
               ScanDefaults.isPlaceholderTitle(entity.title ?? "", createdAt: entity.createdAt) {
                entity.title = suggestedTitle
            }
            entity.updatedAt = Date()
            entity.refreshDerivedFields()
        }
    }

    func appendPages(scanID: UUID, pages: [ScanPage]) async throws {
        try await mutateScan(scanID) { entity, context in
            var nextOrder = (entity.orderedPages.last.map { Int($0.order) } ?? -1) + 1
            for page in pages.sorted(by: { $0.order < $1.order }) {
                let pageEntity = ScanPageEntity.insert(into: context)
                pageEntity.apply(page, order: nextOrder)
                pageEntity.scan = entity
                nextOrder += 1
            }
        }
    }

    func deletePage(scanID: UUID, pageID: UUID) async throws {
        try await mutateScan(scanID) { entity, context in
            let pages = entity.orderedPages
            guard let page = pages.first(where: { $0.id == pageID }) else {
                throw AppError.notFound
            }
            guard pages.count > 1 else {
                throw AppError.lastPageCannotBeDeleted
            }
            context.delete(page)
            for (index, remaining) in pages.filter({ $0 !== page }).enumerated() {
                remaining.order = Int32(index)
            }
        }
    }

    func reorderPages(scanID: UUID, orderedPageIDs: [UUID]) async throws {
        try await mutateScan(scanID) { entity, _ in
            let pages = entity.orderedPages
            let positions = Dictionary(orderedPageIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            // Pages missing from the list keep their relative order at the end.
            let sorted = pages.enumerated().sorted { lhs, rhs in
                let left = lhs.element.id.flatMap { positions[$0] } ?? (orderedPageIDs.count + lhs.offset)
                let right = rhs.element.id.flatMap { positions[$0] } ?? (orderedPageIDs.count + rhs.offset)
                return left < right
            }
            for (index, item) in sorted.enumerated() {
                item.element.order = Int32(index)
            }
        }
    }

    func replacePageImage(scanID: UUID, pageID: UUID, update: PageImageUpdate) async throws {
        try await mutateScan(scanID) { entity, _ in
            guard let page = entity.orderedPages.first(where: { $0.id == pageID }) else {
                throw AppError.notFound
            }
            page.imageData = update.imageData
            page.processedImageData = update.processedImageData
            page.enhancement = update.enhancement.rawValue
            page.thumbnailData = update.thumbnailData
            if update.resetsOCR {
                page.recognizedText = ""
                page.ocrLayoutData = nil
            }
        }
    }

    func delete(scanID: UUID) async throws {
        try await perform { context in
            if let entity = try Self.scanEntity(id: scanID, in: context) {
                context.delete(entity)
            }
        }
    }

    func deleteAll() async throws {
        try await perform { context in
            // Delete object by object so cascade rules and external binary files are cleaned up.
            try context.fetch(ScanEntity.makeFetchRequest()).forEach(context.delete)
        }
    }

    @discardableResult
    func rebuildDerivedFieldsIfNeeded() async throws -> Int {
        try await perform { context in
            let request = ScanEntity.makeFetchRequest()
            request.predicate = NSPredicate(format: "searchText == nil")
            let entities = try context.fetch(request)
            entities.forEach { $0.refreshDerivedFields() }
            if !entities.isEmpty {
                Logger.persistence.info("Rebuilt summary fields for \(entities.count) scans")
            }
            return entities.count
        }
    }

    // MARK: - Helpers

    private func perform<T: Sendable>(_ work: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        do {
            return try await persistenceController.performBackgroundTask(work)
        } catch {
            let appError = AppError.wrap(error, as: AppError.persistence)
            Logger.persistence.error("Repository operation failed: \(appError.debugDetail, privacy: .public)")
            throw appError
        }
    }

    /// Loads a scan, applies `change`, bumps `updatedAt` and refreshes the summary fields.
    private func mutateScan(
        _ scanID: UUID,
        _ change: @escaping @Sendable (ScanEntity, NSManagedObjectContext) throws -> Void
    ) async throws {
        try await perform { context in
            guard let entity = try Self.scanEntity(id: scanID, in: context) else {
                throw AppError.notFound
            }
            try change(entity, context)
            entity.updatedAt = Date()
            entity.refreshDerivedFields()
        }
    }

    private static func scanEntity(id: UUID, in context: NSManagedObjectContext) throws -> ScanEntity? {
        let request = ScanEntity.makeFetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

// MARK: - Mapping

private nonisolated extension ScanEntity {
    func toSummary() -> ScanSummary {
        ScanSummary(
            id: id ?? UUID(),
            createdAt: createdAt ?? .distantPast,
            updatedAt: updatedAt ?? .distantPast,
            title: title ?? ScanDefaults.untitledTitle,
            pageCount: Int(pageCount),
            previewText: previewText ?? "",
            thumbnailData: coverThumbnailData,
            searchText: searchText ?? ScanSearchIndex.normalize(title ?? "")
        )
    }

    func toDomainModel() -> ScanDocument {
        ScanDocument(
            id: id ?? UUID(),
            createdAt: createdAt ?? .distantPast,
            updatedAt: updatedAt ?? .distantPast,
            title: title ?? ScanDefaults.untitledTitle,
            notes: notes ?? "",
            pages: orderedPages.map { $0.toDomainModel() }
        )
    }

    /// Recomputes list/search fields from the current pages.
    func refreshDerivedFields() {
        refreshDerivedFields(pageTexts: orderedPages.map { $0.recognizedText ?? "" },
                             coverThumbnail: orderedPages.first?.thumbnailData,
                             count: orderedPages.count)
    }

    func refreshDerivedFields(pages: [ScanPage]) {
        refreshDerivedFields(pageTexts: pages.map(\.recognizedText),
                             coverThumbnail: pages.first?.thumbnailData,
                             count: pages.count)
    }

    private func refreshDerivedFields(pageTexts: [String], coverThumbnail: Data?, count: Int) {
        pageCount = Int32(count)
        coverThumbnailData = coverThumbnail
        previewText = pageTexts.map(\.normalizedPreview).first(where: { !$0.isEmpty }) ?? ""
        searchText = ScanSearchIndex.searchText(title: title ?? "", notes: notes ?? "", pageTexts: pageTexts)
    }
}

private nonisolated extension ScanPageEntity {
    func toDomainModel() -> ScanPage {
        ScanPage(
            id: id ?? UUID(),
            order: Int(order),
            createdAt: createdAt ?? .distantPast,
            imageData: imageData ?? Data(),
            processedImageData: processedImageData,
            enhancement: enhancement.flatMap(ImageEnhancement.init(rawValue:)) ?? .original,
            thumbnailData: thumbnailData ?? Data(),
            recognizedText: (recognizedText ?? "").normalizedOCRText,
            textObservations: ocrLayoutData.flatMap { try? JSONDecoder().decode([OCRTextObservation].self, from: $0) } ?? []
        )
    }

    func apply(_ page: ScanPage, order: Int) {
        id = page.id
        self.order = Int32(order)
        createdAt = page.createdAt
        imageData = page.imageData
        processedImageData = page.processedImageData
        enhancement = page.enhancement.rawValue
        thumbnailData = page.thumbnailData
        recognizedText = page.recognizedText.normalizedOCRText
        ocrLayoutData = try? JSONEncoder().encode(page.textObservations)
    }
}
