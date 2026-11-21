import Foundation
import UIKit

/// Handles UI-testing launch arguments: resetting or seeding the library and skipping first-run UI.
enum AppSeeder {
    static let emptyArgument = "--ui-testing-empty"
    static let seedArgument = "--ui-testing-seed-scan"
    /// Shows onboarding even though other UI-testing arguments skip it.
    static let onboardingArgument = "--ui-testing-onboarding"

    static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var isUITesting: Bool {
        arguments.contains { $0.hasPrefix("--ui-testing") }
    }

    static func applyLaunchArguments(to settings: AppSettings) {
        guard isUITesting else { return }
        settings.appLockEnabled = false
        settings.hasCompletedOnboarding = !arguments.contains(onboardingArgument)
    }

    static func seedIfNeeded(using repository: ScanRepository) async {
        if arguments.contains(emptyArgument) {
            try? await repository.deleteAll()
            return
        }

        guard arguments.contains(seedArgument) else {
            return
        }

        let existing = (try? await repository.fetchSummaries()) ?? []
        guard existing.isEmpty else {
            return
        }

        let page = ScanPage(
            id: UUID(),
            order: 0,
            createdAt: Date(),
            imageData: seedImageData(),
            thumbnailData: seedImageData(size: CGSize(width: 120, height: 160)),
            recognizedText: "Invoice 2048\nScan Man seeded document",
            textObservations: [
                OCRTextObservation(
                    text: "Invoice 2048",
                    boundingBox: OCRBoundingBox(x: 0.08, y: 0.72, width: 0.32, height: 0.05)
                ),
                OCRTextObservation(
                    text: "Scan Man seeded document",
                    boundingBox: OCRBoundingBox(x: 0.08, y: 0.62, width: 0.54, height: 0.04)
                )
            ]
        )

        let scan = ScanDocument(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            title: "Seeded Invoice",
            notes: "Seeded for UI testing",
            pages: [page]
        )

        try? await repository.save(scan: scan)
    }

    private static func seedImageData(size: CGSize = CGSize(width: 800, height: 1100)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(18, size.width * 0.04), weight: .semibold),
                .foregroundColor: UIColor.black
            ]

            NSString(string: "Scan Man\nSeeded Sample").draw(
                in: CGRect(x: 40, y: 60, width: size.width - 80, height: 200),
                withAttributes: attributes
            )
        }

        return image.jpegData(compressionQuality: 0.9) ?? Data()
    }
}
