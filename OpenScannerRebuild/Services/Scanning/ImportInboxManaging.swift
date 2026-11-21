import Foundation

/// Folders that feed files into the library: the Files-visible import folder and the share-extension inbox.
nonisolated protocol ImportInboxManaging: Sendable {
    var importFolderDisplayPath: String { get }
    func prepareImportLocations() throws
    func pendingImports() throws -> [PendingImportItem]
    func removeImportedItem(_ item: PendingImportItem) throws
}

nonisolated struct PendingImportItem: Equatable, Sendable {
    enum Kind: Sendable {
        case image
        case pdf
    }

    enum Source: Sendable {
        case visibleFolder
        case shareExtension
    }

    let url: URL
    let kind: Kind
    let source: Source
}
