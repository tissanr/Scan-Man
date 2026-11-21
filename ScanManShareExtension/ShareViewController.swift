import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let fileManager = FileManager.default
    // Must match ImportInboxService.appGroupIdentifier in the app target.
    private let appGroupIdentifier = "group.me.tissanr.OpenScannerRebuild"

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        configureUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task { @MainActor in
            await handleIncomingItems()
        }
    }

    private func configureUI() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Saving to Scan Man…"
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    @MainActor
    private func handleIncomingItems() async {
        do {
            let providers = inputProviders()
            guard !providers.isEmpty else {
                finish(with: "Nothing supported was shared.")
                return
            }

            let destinationDirectory = try sharedInboxDirectory()
            var savedCount = 0

            for provider in providers {
                if try await save(provider: provider, into: destinationDirectory) {
                    savedCount += 1
                }
            }

            if savedCount == 0 {
                finish(with: "Scan Man only imports images and PDFs.")
                return
            }

            finish(with: "Saved \(savedCount) item\(savedCount == 1 ? "" : "s"). Open Scan Man to finish import.")
        } catch {
            statusLabel.text = "Scan Man could not save the shared item."
            activityIndicator.stopAnimating()
            try? await Task.sleep(for: .seconds(1.2))
            extensionContext?.cancelRequest(withError: error)
        }
    }

    private func inputProviders() -> [NSItemProvider] {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        return items.flatMap { $0.attachments ?? [] }
    }

    private func sharedInboxDirectory() throws -> URL {
        guard let rootURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let inboxURL = rootURL.appendingPathComponent("Shared Import Inbox", isDirectory: true)
        try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        return inboxURL
    }

    private func save(provider: NSItemProvider, into directory: URL) async throws -> Bool {
        let typeIdentifier: String
        let fallbackExtension: String
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            typeIdentifier = UTType.pdf.identifier
            fallbackExtension = "pdf"
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            typeIdentifier = UTType.image.identifier
            fallbackExtension = "jpg"
        } else {
            return false
        }

        let suggestedName = provider.suggestedName
        if try await copyFileRepresentation(from: provider, typeIdentifier: typeIdentifier, into: directory,
                                            preferredName: suggestedName, fallbackExtension: fallbackExtension) {
            return true
        }

        // Some providers (e.g. in-memory images) only offer data.
        let data = try await loadDataRepresentation(from: provider, typeIdentifier: typeIdentifier)
        try Self.write(data, into: directory, preferredName: suggestedName, pathExtension: fallbackExtension)
        return true
    }

    /// Copies the provider's file. The URL handed to the completion handler is deleted when the
    /// handler returns, so the copy has to happen inside it.
    private func copyFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        into directory: URL,
        preferredName: String?,
        fallbackExtension: String
    ) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { @Sendable url, _ in
                guard let url else {
                    continuation.resume(returning: false)
                    return
                }
                do {
                    let pathExtension = url.pathExtension.isEmpty ? fallbackExtension : url.pathExtension
                    try Self.copy(url, into: directory, preferredName: preferredName, pathExtension: pathExtension)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { @Sendable data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
    }

    // Files are written under a hidden name and then renamed, so the app (which skips hidden
    // files) never imports a half-written file.

    nonisolated private static func copy(_ source: URL, into directory: URL, preferredName: String?, pathExtension: String) throws {
        let fileManager = FileManager.default
        let staging = directory.appendingPathComponent(".staging-\(UUID().uuidString)")
        try fileManager.copyItem(at: source, to: staging)
        try fileManager.moveItem(at: staging, to: uniqueDestinationURL(in: directory, preferredName: preferredName, pathExtension: pathExtension))
    }

    nonisolated private static func write(_ data: Data, into directory: URL, preferredName: String?, pathExtension: String) throws {
        let staging = directory.appendingPathComponent(".staging-\(UUID().uuidString)")
        try data.write(to: staging, options: .atomic)
        try FileManager.default.moveItem(at: staging, to: uniqueDestinationURL(in: directory, preferredName: preferredName, pathExtension: pathExtension))
    }

    nonisolated private static func uniqueDestinationURL(in directory: URL, preferredName: String?, pathExtension: String) -> URL {
        let trimmed = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let baseName = (trimmed.isEmpty ? "Shared Import" : trimmed).replacingOccurrences(of: "/", with: "-")
        let filename = "\(baseName)-\(UUID().uuidString.prefix(8))"
        return directory.appendingPathComponent(filename).appendingPathExtension(pathExtension)
    }

    private func finish(with message: String) {
        statusLabel.text = message
        activityIndicator.stopAnimating()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
