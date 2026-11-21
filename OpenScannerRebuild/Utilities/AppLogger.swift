import Foundation
import OSLog

nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "me.tissanr.OpenScannerRebuild"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let pdf = Logger(subsystem: subsystem, category: "pdf")
    static let importing = Logger(subsystem: subsystem, category: "import")
    static let imaging = Logger(subsystem: subsystem, category: "imaging")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}

/// The app's typed error. Services throw these; view models turn them into alert messages.
nonisolated enum AppError: LocalizedError, Equatable, Sendable {
    case persistence(String)
    case ocr(String)
    case export(String)
    case importFailed(String)
    case imageProcessing(String)
    case scanCapture(String)
    case cameraAccessDenied
    case notFound
    case lastPageCannotBeDeleted
    case unexpected(String)

    /// Wraps any error, keeping existing `AppError` values unchanged.
    static func wrap(_ error: Error, as make: (String) -> AppError) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return make(error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .persistence:
            "Scan Man could not save or load your scans."
        case .ocr:
            "Scan Man could not read the text on this page."
        case .export:
            "Scan Man could not create the export."
        case .importFailed(let detail):
            detail.isEmpty ? "Scan Man could not import that document." : detail
        case .imageProcessing:
            "Scan Man could not process this page image."
        case .scanCapture(let detail):
            detail.isEmpty ? "Scanning failed. Please try again." : detail
        case .cameraAccessDenied:
            "Scan Man needs camera access to scan documents. You can allow it in Settings."
        case .notFound:
            "That scan no longer exists."
        case .lastPageCannotBeDeleted:
            "A scan needs at least one page. Delete the whole scan instead."
        case .unexpected:
            "Something went wrong. Please try again."
        }
    }

    /// Technical detail for logs (never shown to the user).
    var debugDetail: String {
        switch self {
        case .persistence(let d), .ocr(let d), .export(let d), .importFailed(let d),
             .imageProcessing(let d), .scanCapture(let d), .unexpected(let d):
            d
        case .cameraAccessDenied, .notFound, .lastPageCannotBeDeleted:
            String(describing: self)
        }
    }
}
