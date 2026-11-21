import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppLockController.self) private var appLock
    @Environment(\.dismiss) private var dismiss
    @State private var isTogglingLock = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    Picker("Default Filter", selection: $settings.defaultEnhancement) {
                        ForEach(ImageEnhancement.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker("Image Quality", selection: $settings.imageQuality) {
                        ForEach(ImageQuality.allCases) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    Text("Scanning")
                } footer: {
                    Text("The filter applies to new pages; you can change it per page later. Lower quality makes smaller files.")
                }

                Section {
                    Picker("Page Size", selection: $settings.pdfPageSize) {
                        ForEach(PDFPageSize.allCases) { Text($0.displayName).tag($0) }
                    }
                } header: {
                    Text("PDF Export")
                } footer: {
                    Text("Fit to Image makes each PDF page the same shape as the scan.")
                }

                Section {
                    Toggle("Require \(AppLockController.biometryName)", isOn: Binding(
                        get: { settings.appLockEnabled },
                        set: { enabled in
                            if enabled {
                                isTogglingLock = true
                                Task {
                                    _ = await appLock.enableLock()
                                    isTogglingLock = false
                                }
                            } else {
                                appLock.disableLock()
                            }
                        }
                    ))
                    .disabled(isTogglingLock || !AppLockController.isAvailable)
                    .accessibilityIdentifier("AppLockToggle")
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(AppLockController.isAvailable
                         ? "Scan Man locks when you leave the app and hides your documents in the app switcher."
                         : "Set up a device passcode to use app lock.")
                }

                Section("Import Folder") {
                    Text("Put images or PDFs in Files › On My iPhone › Scan Man › Scan Man Imports. They're added to your library the next time you open Scan Man.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Version", value: Self.versionString)
                } header: {
                    Text("About")
                } footer: {
                    Text("Scan Man stores everything on this device. It has no accounts, no analytics and makes no network connections.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
