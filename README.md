# Scan Man

Scan Man is a local-first iOS document scanner built with Apple frameworks only.

## Stack

- iOS 16+
- SwiftUI for app UI
- VisionKit for document capture
- Vision for OCR
- PDFKit and Core Graphics for export
- Core Data for local persistence

## Local Build Notes

- Open `OpenScannerRebuild.xcodeproj` in Xcode 16 or newer.
- Select a Personal Team signing identity for the app target.
- The app is designed to run fully offline with local storage only.
- Camera scanning is unavailable in the simulator; the app should show a friendly message instead of crashing.
- UI tests can seed demo content by launching with `--ui-testing-seed-scan`.

## Current Status

- Clean architecture baseline is in place.
- Home and detail flows use local Core Data-backed models.
- VisionKit capture, OCR-backed search, text export, and searchable PDF export are implemented.
- The next planned phase is OCR geometry alignment for better searchable PDF text placement.
