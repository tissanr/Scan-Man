import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let fileManager = FileManager.default
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.extensionContext?.cancelRequest(withError: error)
            }
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
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            try await copyFileRepresentation(from: provider, typeIdentifier: UTType.pdf.identifier, into: directory, fallbackExtension: "pdf")
            return true
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            if (try? await copyFileRepresentation(from: provider, typeIdentifier: UTType.image.identifier, into: directory, fallbackExtension: "jpg")) != nil {
                return true
            }

            let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.image.identifier)
            let destinationURL = Self.uniqueDestinationURL(in: directory, preferredName: provider.suggestedName, pathExtension: "jpg")
            try data.write(to: destinationURL, options: .atomic)
            return true
        }

        return false
    }

    nonisolated private static func uniqueDestinationURL(in directory: URL, preferredName: String?, pathExtension: String) -> URL {
        let baseName = (preferredName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? preferredName! : "Shared Import")
            .replacingOccurrences(of: "/", with: "-")
        let filename = "\(baseName)-\(UUID().uuidString.prefix(8))"
        return directory.appendingPathComponent(filename).appendingPathExtension(pathExtension)
    }

    /// Copies the provider's file into the inbox. The URL handed to the completion handler is
    /// deleted as soon as the handler returns, so the copy has to happen inside it.
    private func copyFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        into directory: URL,
        fallbackExtension: String
    ) async throws {
        let preferredName = provider.suggestedName
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                guard let url else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    return
                }

                do {
                    let pathExtension = url.pathExtension.isEmpty ? fallbackExtension : url.pathExtension
                    let destinationURL = Self.uniqueDestinationURL(in: directory, preferredName: preferredName, pathExtension: pathExtension)
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                }
            }
        }
    }

    private func finish(with message: String) {
        statusLabel.text = message
        activityIndicator.stopAnimating()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
