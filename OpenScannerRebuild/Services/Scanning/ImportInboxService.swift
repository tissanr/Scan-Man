import Foundation
import UniformTypeIdentifiers

struct ImportInboxService: ImportInboxManaging {
    private let fileManager: FileManager
    private let appGroupIdentifier: String

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = "group.me.tissanr.OpenScannerRebuild"
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier
    }

    var importFolderDisplayPath: String {
        "Files > On My iPhone > Scan Man > Scan Man Imports"
    }

    func prepareImportLocations() throws {
        try ensureDirectory(at: visibleImportFolderURL())
        if let sharedURL = sharedInboxURL() {
            try ensureDirectory(at: sharedURL)
        }
    }

    func pendingImports() throws -> [PendingImportItem] {
        try prepareImportLocations()

        let visibleItems = try importItems(in: visibleImportFolderURL(), source: .visibleFolder)
        let sharedItems = try sharedInboxURL().map { try importItems(in: $0, source: .shareExtension) } ?? []
        return (visibleItems + sharedItems)
            .sorted { lhs, rhs in
                lhs.url.lastPathComponent.localizedCaseInsensitiveCompare(rhs.url.lastPathComponent) == .orderedAscending
            }
    }

    func removeImportedItem(_ item: PendingImportItem) throws {
        guard fileManager.fileExists(atPath: item.url.path) else {
            return
        }

        try fileManager.removeItem(at: item.url)
    }

    private func visibleImportFolderURL() -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return documentsURL.appendingPathComponent("Scan Man Imports", isDirectory: true)
    }

    private func sharedInboxURL() -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("Shared Import Inbox", isDirectory: true)
    }

    private func ensureDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func importItems(in directoryURL: URL, source: PendingImportItem.Source) throws -> [PendingImportItem] {
        let fileURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        )

        return try fileURLs.compactMap { url in
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey])
            guard resourceValues.isRegularFile == true else {
                return nil
            }

            let contentType = resourceValues.contentType ?? UTType(filenameExtension: url.pathExtension)
            if contentType?.conforms(to: .image) == true {
                return PendingImportItem(url: url, kind: .image, source: source)
            }

            if contentType?.conforms(to: .pdf) == true {
                return PendingImportItem(url: url, kind: .pdf, source: source)
            }

            return nil
        }
    }
}
