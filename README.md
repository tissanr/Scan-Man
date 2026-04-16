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
- Phase 5 is implemented as Apple-native input and lightweight editing expansion:
  - import from Photos and PDF files maps into the same local `ScanDocument`/`ScanPage` model as camera scans
  - imported scans go through the same OCR, search, detail, and export paths as scanner-created scans
  - scan-level local notes provide minimal annotation without changing the PDF export pipeline
  - a Files-visible inbox now exists at `Files > On My iPhone > Scan Man > Scan Man Imports`
  - Scan Man re-checks that inbox whenever the app becomes active and imports supported image/PDF files into the library
  - the iOS share menu can send images and PDFs to the Scan Man share extension, which stages them for the same import/OCR flow

## Phase 5 Export And Sync Decision

- v1 baseline: keep `UIActivityViewController` share/export and Files providers as the default export path. This already covers AirDrop, Mail, Messages, Files, and installed document providers with the lowest implementation and support cost.
- Defer saved destinations and one-tap repeat export. They are viable on top of Apple document APIs and security-scoped bookmarks, but they add state management and recovery work that is not necessary for the first useful version.
- Do not add direct Nextcloud export in v1. A WebDAV flow would need account storage, app-password handling, remote folder selection, upload progress, retries, and conflict semantics before it becomes more valuable than the system share sheet.
- Do not add Syncthing-specific sync in v1. iOS sandboxing and background limits make it a constrained handoff problem rather than a clean native sync integration, so the practical baseline remains Files-based export into any user-managed folder workflow.
- Keep local-only behavior as a first-class mode. Optional sync can be evaluated later only if it is isolated from the local data path and does not weaken offline reliability.

## Phase 5 Import Notes

- Files inbox path on device: `Files > On My iPhone > Scan Man > Scan Man Imports`
- Supported inbox payloads: images and PDFs
- Shared images/PDFs are first staged by the share extension, then imported into the main library the next time Scan Man becomes active
- Imported source files are consumed from the inbox after a successful import so they are not duplicated on every launch
- The share extension uses an App Group to pass files to the main app, which means signing must allow the `group.me.tissanr.OpenScannerRebuild` capability
