# Scan Man Spec

## Goal

Build a native iOS document scanning app called Scan Man using Apple frameworks only. The app should be local-first, reliable, and easy to extend.

## Product Requirements

- Scan paper documents with the camera.
- Run OCR on scanned pages.
- Store scans locally.
- Browse, search, edit, and share scans.
- Export both image PDFs and searchable PDFs.
- Run fully without iCloud in v1.

## Platform

- iOS 17+
- Swift 5+
- SwiftUI
- VisionKit
- Vision
- PDFKit/Core Graphics
- Core Data
- No third-party dependencies

## Architecture

- `App`
- `Features/Home`
- `Features/Scan`
- `Features/ScanDetail`
- `Features/Share`
- `Data/CoreData`
- `Domain/Models`
- `Services/OCR`
- `Services/PDFExport`
- `Services/Scanning`
- `UI/Components`
- `Utilities`

## v1 Constraints

- No CloudKit
- No push notifications
- No widgets
- No App Intents
- No third-party packages
- No deprecated window APIs

## Key Acceptance Criteria

- Multi-page scans save locally.
- OCR text is searchable.
- PDF export works offline.
- Searchable PDF contains selectable text.
- App builds with Personal Team signing.
- Basic unit and UI tests pass.

## Delivered Status

- Phase 1: delivered
- Phase 2: delivered
- Phase 3: delivered
- Phase 4: delivered
- Phase 5: next
- Phase 6: planned

## Next Formal Phases

### Phase 5: Optional Sync And Extended Inputs

Goal:

- Evaluate the next layer of convenience features without compromising the local-first baseline, with special attention to export paths.

Requirements:

- Consider optional iCloud sync only if it preserves reliable offline behavior.
- Keep Apple-native export and share flows as the default v1 approach.
- Evaluate export targets by complexity and product value:
  - Lowest complexity: `UIActivityViewController` and document picker based export to the share sheet and Files providers already installed on iOS.
  - Low-to-medium complexity: repeated export conveniences like remembered destinations, export presets, or one-tap re-export built on security-scoped bookmarks.
  - Medium-to-high complexity: direct Nextcloud export via WebDAV, including credentials, app passwords, folder browsing, upload progress, retries, and conflict handling.
  - High complexity: Syncthing-specific export or sync, because iOS does not provide a native Syncthing framework and the app would need either a companion-app handoff or a constrained filesystem-based workflow.
- Prefer generic Apple document flows over provider-specific integrations unless a provider unlocks meaningful workflow value beyond the system share/export options.
- Evaluate importing from photos or PDFs.
- Explore annotations or other lightweight editing that fits the current architecture.

Prompt:

Implement the next phase for Scan Man using Apple frameworks first. Preserve the local-first architecture while evaluating optional sync, broader import sources, lightweight annotation or editing features, and the export decision space. Treat Apple-native share/export support as the baseline, document the complexity tradeoffs of direct Nextcloud and Syncthing integrations, and only implement provider-specific export if it clearly adds workflow value beyond the standard system flows.

### Phase 6: Rollout Preparation

Goal:

- Prepare Scan Man for real-user rollout through TestFlight and App Store submission.

Requirements:

- Stabilize the product around the delivered scan, OCR, editing, and export feature set.
- Audit release-blocking UX issues: permission prompts, empty states, error recovery, and first-run guidance.
- Finalize release assets and compliance items:
  - app name, bundle identifier, versioning, icons, screenshots, and App Store copy
  - privacy policy URL and App Privacy details
  - export compliance answers for submission
- Build a rollout checklist covering internal beta, external TestFlight, crash and feedback triage, and go/no-go criteria.
- Expand validation with release-focused unit, UI, and device smoke tests.

Prompt:

Implement Phase 6 for Scan Man as a rollout-preparation phase. Focus on release hardening, TestFlight readiness, App Store metadata and compliance preparation, and a practical staged rollout plan. Do not add large net-new product scope unless it directly reduces rollout risk.
