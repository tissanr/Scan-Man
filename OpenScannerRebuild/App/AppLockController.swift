import Foundation
import LocalAuthentication
import Observation
import OSLog

/// Locks the app behind Face ID / Touch ID / passcode when it goes to the background.
@MainActor
@Observable
final class AppLockController {
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        isLocked = settings.appLockEnabled
    }

    /// Whether the device has a passcode or biometrics set up (required for app lock).
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    func sceneDidEnterBackground() {
        if settings.appLockEnabled {
            isLocked = true
        }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        guard settings.appLockEnabled else {
            isLocked = false
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        let context = LAContext()
        do {
            if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your scans") {
                isLocked = false
                lastErrorMessage = nil
            }
        } catch {
            Logger.lifecycle.info("App unlock failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "Authentication failed. Try again."
        }
    }

    /// Verifies the user before turning the lock on, so they can't lock themselves out.
    func enableLock() async -> Bool {
        let context = LAContext()
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Turn on app lock")
            if ok { settings.appLockEnabled = true }
            return ok
        } catch {
            return false
        }
    }

    func disableLock() {
        settings.appLockEnabled = false
        isLocked = false
    }
}
