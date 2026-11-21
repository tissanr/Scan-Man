# Roadmap

## Status

| Phase | Topic | Status |
|---|---|---|
| 1 | App shell, capture, local storage, plain PDF | Delivered |
| 2 | OCR, search, title suggestions, text export | Delivered |
| 3 | OCR geometry, aligned searchable PDF | Delivered |
| 4 | Simulator fallback, text editing, OCR overlay | Delivered |
| 5 | Photo/PDF import, import folder, share extension | Delivered |
| 7 | CI, logging, `AppError`, benchmarks | Delivered (finished in 6a) |
| 8 | Makefile, DocC, DI, screenshot automation | Delivered |
| 9 | Migration tests, accessibility audits, coverage, snapshots | Delivered (finished in 6a) |
| 6a | Bug fixes, docs match code | Delivered |
| 6b | Core scanner features | Delivered (needs device testing) |
| 6c | Release preparation | In progress: code done, manual steps open |
| Post-v1 | Spotlight, organization, Shortcuts, smarter titles | Planned |
| 10–12 | iCloud sync, WebDAV export, auto-export | Planned (after v1) |

Phase 6 was split in three: release work only makes sense once the core scanning workflow is complete and the known bugs are fixed.

## Phase 1

- Replace the template app with the Scan Man shell.
- Define Core Data entities for scans and pages.
- Build the home list, scan detail screen, and full-page preview.
- Add VisionKit document capture, local persistence, and plain PDF export.

## Phase 2

- Integrate the Vision OCR pipeline.
- Add scan text search and title suggestions.
- Export text in page order.

## Phase 3

- Store OCR geometry, not just flattened page text.
- Align the searchable PDF text layer with the page image.

## Phase 4

- Simulator-friendly fallback and UI tests for core library flows.
- Editing of extracted page text.
- In-app OCR overlay using stored geometry.

## Phase 5: Extended Inputs

- Import from Photos and PDF files through the same pipeline as camera scans.
- Files-visible import folder (`Files > On My iPhone > Scan Man > Scan Man Imports`).
- Share extension for images and PDFs; images shared together become one multi-page scan.
- Export decision: the system share sheet and Files are the v1 export story. Nextcloud/WebDAV, Syncthing and saved destinations are post-v1 (Phases 10–12).

## Phase 7: Core Infrastructure & Performance

- GitHub Actions CI.
- Structured logging with `Logger` categories (`AppLogger.swift`).
- Typed `AppError`, thrown by services and turned into alerts by view models.
- Performance budgets for the library list and PDF export.

## Phase 8: Developer Tooling & Documentation

- `Makefile` for build, test, docs, screenshots.
- DocC comments on public APIs.
- Dependency injection through `AppDependencies`.
- Automated App Store screenshots via UI tests.

## Phase 9: Advanced Validation & Accessibility

- Core Data migration test: a store written with model v1 is opened with model v2.
- Automated accessibility audits in UI tests (structural audits; visual audits are skipped on the simulator).
- Code coverage report and threshold in CI (`scripts/check-coverage.py`).
- Pixel snapshot tests for the OCR overlay (`OpenScannerRebuildTests/__Snapshots__`).

## Phase 6a: Fixes and Making Docs Match Code

- OCR results are merged per page and never overwrite text or titles the user changed; results for deleted scans are dropped.
- Searchable PDFs contain each line once, as invisible text placed on its OCR box.
- The library list loads lightweight summaries instead of every page image; page images use external storage (model v2).
- Imported photos are normalized upright and OCR honors EXIF orientation.
- OCR, imaging, import and export run off the main actor.
- Temporary exports are cleaned up; the share extension no longer loses files.
- Swift 6 language mode on Xcode 26, matching the project's default-MainActor settings; CI uses the same toolchain.
- Finished the Phase 7 and 9 items that existed only on paper.

## Phase 6b: Core Scanner Features

- Page management: reorder, delete, rotate, crop with perspective correction and automatic edge detection, add pages by scanning or from Photos.
- Per-page filters: Original, Enhanced, Grayscale, Black & White. Non-destructive: the original is kept and OCR always reads it.
- Settings: default filter, image quality (resolution and compression), PDF page size (A4, US Letter, Fit to Image).
- App lock with Face ID / Touch ID / passcode, plus a privacy cover in the app switcher.
- Store encrypted at rest while the device is locked (`completeUnlessOpen`).

Open: test on physical devices (camera capture, Face ID, large documents, share extension from Photos/Files/Mail).

## Phase 6c: Release Preparation

Done in code:

- First-run onboarding, camera-permission handling with a link to Settings, empty states, a screen for a library that fails to open.
- Privacy manifests for the app and share extension; `ITSAppUsesNonExemptEncryption = NO`; Face ID and camera usage strings.

Open (manual, see `RELEASE.md`):

- App icon artwork (the asset catalog has no image yet).
- Privacy policy URL, App Store copy, screenshots on required device sizes.
- TestFlight internal and external beta, crash and feedback triage, go/no-go review.

## Post-v1

Apple frameworks only, in rough priority order:

- **Spotlight**: index OCR text with Core Spotlight so scans show up in system search.
- **Organization**: folders or tags once libraries grow past a few dozen scans.
- **Shortcuts / App Intents**: "Scan to PDF", "Find a scan". Excluded from v1 by `SPEC.md`.
- **Smarter titles**: dates, amounts and senders from `NSDataDetector` for receipts and invoices.

## Phase 10: iCloud Sync (CloudKit)

- `NSPersistentCloudKitContainer`, opt-in toggle, local-only stays a first-class mode.

## Phase 11: WebDAV / Nextcloud Export

- `URLSession` WebDAV client, credentials in the Keychain, direct PDF upload.

## Phase 12: Auto-Export & Syncthing Helper

- Mirror scans to a user-chosen Files folder (security-scoped bookmark) for Syncthing/Möbius Sync users.
