# Scan Man

Scan Man is a local-first iOS document scanner built with Apple frameworks only.

## Stack

- iOS 17+
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

- Delivered phases: 1, 2, 3, 4
- Clean architecture baseline is in place.
- Home and detail flows use local Core Data-backed models.
- VisionKit capture, OCR-backed search, per-page OCR text editing, text export, and searchable PDF export with OCR geometry alignment are implemented.
- Page detail now includes OCR geometry-aware preview overlays and a richer in-app reading presentation when layout data is available.
- Simulator fallback is explicit in the UI when document scanning is unavailable.
- UI tests cover the home screen, scan entry fallback, opening saved scans, searching, page preview, and page text editing.
- The next planned phase is optional sync and broader import/editing exploration.
