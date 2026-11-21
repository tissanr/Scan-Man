import Foundation
import Observation

/// User preferences, persisted in `UserDefaults`.
@MainActor
@Observable
final class AppSettings {
    private enum Keys {
        static let enhancement = "settings.defaultEnhancement"
        static let pageSize = "settings.pdfPageSize"
        static let quality = "settings.imageQuality"
        static let appLock = "settings.appLockEnabled"
        static let onboarding = "settings.hasCompletedOnboarding"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Filter applied to newly scanned or imported pages.
    var defaultEnhancement: ImageEnhancement {
        didSet { defaults.set(defaultEnhancement.rawValue, forKey: Keys.enhancement) }
    }

    var pdfPageSize: PDFPageSize {
        didSet { defaults.set(pdfPageSize.rawValue, forKey: Keys.pageSize) }
    }

    /// Resolution and compression for stored pages and exports.
    var imageQuality: ImageQuality {
        didSet { defaults.set(imageQuality.rawValue, forKey: Keys.quality) }
    }

    /// Require Face ID / Touch ID / passcode when returning to the app.
    var appLockEnabled: Bool {
        didSet { defaults.set(appLockEnabled, forKey: Keys.appLock) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultEnhancement = defaults.string(forKey: Keys.enhancement).flatMap(ImageEnhancement.init(rawValue:)) ?? .original
        pdfPageSize = defaults.string(forKey: Keys.pageSize).flatMap(PDFPageSize.init(rawValue:)) ?? .regionDefault()
        imageQuality = defaults.string(forKey: Keys.quality).flatMap(ImageQuality.init(rawValue:)) ?? .high
        appLockEnabled = defaults.bool(forKey: Keys.appLock)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    }

    var importOptions: ImportOptions {
        ImportOptions(enhancement: defaultEnhancement, quality: imageQuality)
    }

    var exportOptions: PDFExportOptions {
        PDFExportOptions(pageSize: pdfPageSize, quality: imageQuality)
    }
}
