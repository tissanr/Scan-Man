# Open Scanner Spec

## Goal

Build a native iOS document scanning app called Open Scanner using Apple frameworks only. The app should be local-first, reliable, and easy to extend.

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

## Next Formal Phase

### Phase 4: OCR Editing And Presentation

Goal:

- Improve simulator behavior, let users refine OCR text, and use stored OCR geometry more directly in the app UI.

Requirements:

- Keep simulator behavior explicit and graceful when scanning cannot run.
- Add lightweight per-page OCR text editing without breaking search or export.
- Use stored OCR geometry to improve the in-app reading experience where it adds value.
- Keep exports resilient when OCR geometry is partial or unavailable.

Prompt:

Implement Phase 4 for Scan Man using Apple frameworks only. Improve simulator-friendly fallback behavior, expand UI test coverage, allow lightweight editing of extracted OCR text per page, and add richer in-app OCR presentation using the stored OCR geometry. Preserve local-first behavior, export compatibility, and graceful fallback when OCR geometry is missing or incomplete.
