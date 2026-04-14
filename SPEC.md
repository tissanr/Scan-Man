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

## Next Formal Phase

### Phase 5: Optional Sync And Extended Inputs

Goal:

- Evaluate the next layer of convenience features without compromising the local-first baseline.

Requirements:

- Consider optional iCloud sync only if it preserves reliable offline behavior.
- Evaluate importing from photos or PDFs.
- Explore annotations or other lightweight editing that fits the current architecture.

Prompt:

Implement the next phase for Scan Man using Apple frameworks only. Preserve the local-first architecture while evaluating optional sync, broader import sources, and lightweight annotation or editing features that build on the existing scan, OCR, and export flows.
