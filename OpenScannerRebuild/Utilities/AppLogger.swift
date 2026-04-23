import Foundation
import OSLog

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.scanner.OpenScannerRebuild"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let pdf = Logger(subsystem: subsystem, category: "pdf")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}

enum AppError: LocalizedError {
    case persistence(Error)
    case ocr(Error)
    case pdfExport(Error)
    case scanCapture(String)
    case unexpected(Error)

    var errorDescription: String? {
        switch self {
        case .persistence(let error): return "Database error: \(error.localizedDescription)"
        case .ocr(let error): return "OCR processing failed: \(error.localizedDescription)"
        case .pdfExport(let error): return "PDF export failed: \(error.localizedDescription)"
        case .scanCapture(let message): return "Capture error: \(message)"
        case .unexpected(let error): return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
