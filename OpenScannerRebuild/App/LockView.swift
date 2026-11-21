import SwiftUI

struct LockView: View {
    let appLock: AppLockController

    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Scan Man is Locked")
                    .font(.title2.bold())
                if let message = appLock.lastErrorMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
                Button("Unlock with \(AppLockController.biometryName)") {
                    Task { await appLock.unlock() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appLock.isAuthenticating)
            }
            .padding(32)
        }
    }
}

/// Covers the UI while the app is inactive so documents don't appear in the app switcher.
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
        }
        .accessibilityHidden(true)
    }
}
