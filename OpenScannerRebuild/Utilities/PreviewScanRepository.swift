import Foundation

struct PreviewScanRepository: ScanRepository {
    func fetchScans() async throws -> [ScanDocument] {
        [
            ScanDocument(
                id: UUID(),
                createdAt: Date(),
                updatedAt: Date(),
                title: "Receipt",
                pages: [
                    ScanPage(
                        id: UUID(),
                        order: 0,
                        createdAt: Date(),
                        imageData: Data(),
                        thumbnailData: Data(),
                        recognizedText: "Coffee beans and pastries"
                    )
                ]
            )
        ]
    }

    func save(scan: ScanDocument) async throws {
    }

    func updateTitle(scanID: UUID, title: String) async throws {
    }

    func delete(scanID: UUID) async throws {
    }

    func deleteAll() async throws {
    }
}
