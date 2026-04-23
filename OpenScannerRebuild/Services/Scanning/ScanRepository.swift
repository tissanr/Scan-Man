import Foundation

/// A protocol defining the storage operations for scan documents.
///
/// Use this protocol to implement persistence layers for the application.
protocol ScanRepository {
    /// Fetches all stored scans.
    /// - Returns: An array of ``ScanDocument`` objects.
    func fetchScans() async throws -> [ScanDocument]
    
    /// Fetches a specific scan by its unique identifier.
    /// - Parameter id: The UUID of the scan to fetch.
    /// - Returns: A ``ScanDocument`` if found, otherwise nil.
    func fetchScan(id: UUID) async throws -> ScanDocument?
    
    /// Saves or updates a scan document.
    /// - Parameter scan: The ``ScanDocument`` to persist.
    func save(scan: ScanDocument) async throws
    
    /// Updates the title of a specific scan.
    /// - Parameters:
    ///   - scanID: The identifier of the scan to update.
    ///   - title: The new title for the scan.
    func updateTitle(scanID: UUID, title: String) async throws
    
    /// Updates the notes for a specific scan.
    /// - Parameters:
    ///   - scanID: The identifier of the scan to update.
    ///   - notes: The new notes content.
    func updateNotes(scanID: UUID, notes: String) async throws
    
    /// Updates the recognized text for a specific page within a scan.
    /// - Parameters:
    ///   - scanID: The identifier of the scan.
    ///   - pageID: The identifier of the page within the scan.
    ///   - text: The new recognized text content.
    func updateRecognizedText(scanID: UUID, pageID: UUID, text: String) async throws
    
    /// Deletes a specific scan document.
    /// - Parameter scanID: The identifier of the scan to delete.
    func delete(scanID: UUID) async throws
    
    /// Deletes all stored scan documents.
    func deleteAll() async throws
}
