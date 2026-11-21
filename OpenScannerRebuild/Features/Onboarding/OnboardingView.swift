import SwiftUI

/// First-run introduction.
struct OnboardingView: View {
    let importFolderPath: String
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Welcome to Scan Man")
                        .font(.largeTitle.bold())
                }

                FeatureRow(
                    systemImage: "camera.viewfinder",
                    title: "Scan and import",
                    message: "Scan paper with the camera, or import photos and PDFs. You can also share files to Scan Man from other apps."
                )
                FeatureRow(
                    systemImage: "text.magnifyingglass",
                    title: "Searchable text",
                    message: "Text is recognized on your device, so you can search your scans and export searchable PDFs."
                )
                FeatureRow(
                    systemImage: "lock.shield",
                    title: "Private by design",
                    message: "Your scans never leave this device unless you share them. Turn on Face ID lock in Settings."
                )
                FeatureRow(
                    systemImage: "folder",
                    title: "Import folder",
                    message: "Files you put in \(importFolderPath) are imported automatically."
                )
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(24)
            .accessibilityIdentifier("GetStarted")
        }
    }
}

private struct FeatureRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
