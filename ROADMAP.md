# Roadmap

## Status (reviewed 2026-10-26)

| Phase | Topic | Status |
|---|---|---|
| 1 | App shell, Core Data, capture, plain PDF | Delivered |
| 2 | Vision OCR, search, title suggestions | Delivered |
| 3 | OCR geometry, aligned searchable PDF | Delivered |
| 4 | Simulator fallbacks, text editing, OCR overlay | Delivered |
| 5 | Import (Photos, PDF, Files inbox, share extension), notes | Delivered |
| 7 | CI, logging, error types, benchmarks | Partially delivered — `Logger` categories and `AppError` exist but are not used yet |
| 8 | Makefile, DocC, DI, screenshot test | Delivered |
| 9 | Migration tests, accessibility audits, coverage, snapshots | Partially delivered — see below |
| 6 | Rollout preparation | Planned (next) |
| 10 | Platform modernization | Planned |
| 11 | Post-v1 features | Ideas |

Phases 7–9 were inserted before Phase 6, which is why the numbering is out of order.

## Phase 1

- Replace the template app with the Scan Man shell.
- Define Core Data entities for scans and pages.
- Build the home list, scan detail screen, and full-page preview.
- Add VisionKit document capture, local persistence, and plain PDF export.

## Phase 2

- Integrate Vision OCR pipeline.
- Add scan text search and title suggestions.
- Export text in page order.
- Expand unit coverage around OCR mapping, searchable PDF output, and preview logic.

## Phase 3

- Store OCR geometry, not just flattened page text.
- Improve searchable PDF alignment so hidden/selectable text matches the scanned page image closely.
- Prepare the app for future in-image text overlays and more precise text selection behavior.
- Add focused tests around OCR box mapping and aligned PDF export.

## Phase 4

- Improve simulator-friendly fallback handling and expand UI tests for core library flows.
- Allow lightweight editing of extracted page text where practical.
- Explore richer in-app OCR presentation using stored geometry.

## Phase 5

- Apple share sheet and Files remain the export story; direct Nextcloud/WebDAV and Syncthing are out of scope for v1 (rationale in `README.md`).
- Import from Photos and PDF files into the same scan model and OCR pipeline.
- Files-visible import inbox (`Scan Man Imports`) and share-extension intake for images and PDFs.
- Scan-level notes as lightweight annotation.

## Phase 7: Core Infrastructure & Performance

- Delivered: GitHub Actions CI, `OSLog` categories, `AppError` type, Core Data / PDF export performance tests.
- Open: actually log through the `Logger` categories (no call sites yet) and decide whether `AppError` replaces the per-service error enums or is removed.

## Phase 8: Developer Tooling & Documentation

- `Makefile` for standard tasks (simulator auto-detected via `scripts/simulator-destination.sh`).
- DocC comments on service protocols.
- `AppDependencies` container.
- Screenshot UI test for App Store assets.

## Phase 9: Advanced Validation & Accessibility

- Delivered: `performAccessibilityAudit()` in UI tests; coverage collected in CI with a per-target summary.
- Open: migration tests are a placeholder until a second model version exists; no coverage threshold gate; no snapshot tests for OCR overlays.

## Phase 6: Rollout Preparation (next)

- Harden onboarding, permissions, error states, and empty states.
- Finalize app identity assets, App Store metadata, privacy policy URL, App Privacy details and export compliance answers.
- Add a privacy manifest (`PrivacyInfo.xcprivacy`) for the app and the share extension — required for App Store submission.
- Build with the current SDK: App Store Connect requires the iOS 26 SDK (Xcode 26+); CI already runs on `macos-26`.
- Device testing, migration checks, import/export smoke tests, crash review.
- Staged rollout: internal TestFlight → external beta → feedback triage → release criteria.

## Phase 10: Platform Modernization

What we would do differently if starting today, ordered by value vs. risk:

1. **Keep heavy work off the main actor.** The app target defaults to `MainActor` isolation. OCR is now `@concurrent`; PDF/photo import rendering and PDF export still run on the main thread and freeze the UI for large documents.
2. **Stop loading full-resolution images for the library list.** `fetchScans()` materialises every page's `imageData`. Store page images as files (or enable *Allows External Storage*) and fetch a lightweight summary for the list; decode images lazily.
3. **Swift 6 language mode.** The code already uses approachable concurrency; switching to Swift 6 turns the remaining data-race warnings into compile-time guarantees. `PersistenceController.performBackgroundTask` should then use `NSPersistentContainer.performBackgroundTask` async overload.
4. **`@Observable` instead of `ObservableObject`.** Supported since iOS 17 (current minimum); removes `@Published`/Combine and gives finer-grained view updates.
5. **Model versioning before the next schema change.** Introduce `OpenScannerRebuild 2.xcdatamodel` and turn the placeholder migration test into a real v1→v2 test. SwiftData is not worth a migration for this app; stay on Core Data.
6. **Newer Vision APIs.** Raising the minimum to iOS 18 enables the Swift-native `RecognizeTextRequest`; iOS 26's `RecognizeDocumentsRequest` adds paragraph/table structure, which would improve text export and searchable PDFs.
7. **Inbox robustness.** Files that fail to import stay in the inbox and raise an alert on every activation; move them to a `Failed` subfolder instead.
8. **Liquid Glass review.** Building with the iOS 26 SDK adopts the new design automatically; check the custom bottom inset (`.background(.bar)`) and sheets on device.

## Phase 11: Post-v1 Ideas

- App Intents / Shortcuts ("Scan document", "Find scan") and Spotlight indexing of OCR text (excluded from v1 by `SPEC.md`).
- Page reordering, deletion and rotation within a scan.
- Optional iCloud sync, isolated from the local data path.
- Saved export destinations via security-scoped bookmarks.
