import Foundation

protocol ScanRepository {
    func fetchScans() async throws -> [ScanDocument]
    func fetchScan(id: UUID) async throws -> ScanDocument?
    func save(scan: ScanDocument) async throws
    func updateTitle(scanID: UUID, title: String) async throws
    func delete(scanID: UUID) async throws
    func deleteAll() async throws
}
