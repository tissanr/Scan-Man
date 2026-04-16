import Foundation

protocol ImportInboxManaging {
    var importFolderDisplayPath: String { get }
    func prepareImportLocations() throws
    func pendingImports() throws -> [PendingImportItem]
    func removeImportedItem(_ item: PendingImportItem) throws
}

struct PendingImportItem: Equatable, Sendable {
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
