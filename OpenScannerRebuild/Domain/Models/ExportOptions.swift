import CoreGraphics
import Foundation

/// Page size used when writing PDFs.
nonisolated enum PDFPageSize: String, CaseIterable, Identifiable, Sendable {
    /// Each PDF page takes the aspect ratio of its scanned image.
    case fitToImage
    case a4
    case letter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitToImage: "Fit to Image"
        case .a4: "A4"
        case .letter: "US Letter"
        }
    }

    /// Paper size in PDF points, or nil when the page follows the image.
    var paperSize: CGSize? {
        switch self {
        case .fitToImage: nil
        case .a4: CGSize(width: 595.28, height: 841.89)
        case .letter: CGSize(width: 612, height: 792)
        }
    }

    /// Letter in the US and Canada, A4 elsewhere.
    static func regionDefault(for locale: Locale = .current) -> PDFPageSize {
        switch locale.region?.identifier {
        case "US", "CA", "MX", "PH": .letter
        default: .a4
        }
    }
}

/// Image quality used for stored pages and exports; controls resolution and JPEG compression.
nonisolated enum ImageQuality: String, CaseIterable, Identifiable, Sendable {
    case high
    case medium
    case small

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .small: "Small File"
        }
    }

    var maxPixelDimension: CGFloat {
        switch self {
        case .high: 3000
        case .medium: 2200
        case .small: 1600
        }
    }

    var jpegQuality: CGFloat {
        switch self {
        case .high: 0.85
        case .medium: 0.7
        case .small: 0.55
        }
    }
}

nonisolated enum PDFExportMode: Sendable {
    /// Images only.
    case imageOnly
    /// Images plus an invisible, selectable text layer aligned with the page.
    case searchable
}

nonisolated struct PDFExportOptions: Equatable, Sendable {
    var pageSize: PDFPageSize
    var quality: ImageQuality

    static let standard = PDFExportOptions(pageSize: .a4, quality: .high)
}

/// Settings applied to pages when they enter the library.
nonisolated struct ImportOptions: Equatable, Sendable {
    var enhancement: ImageEnhancement
    var quality: ImageQuality

    static let standard = ImportOptions(enhancement: .original, quality: .high)
}
