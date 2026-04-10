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

- iOS 16+
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

### Phase 3: OCR Geometry Alignment

Goal:

- Improve searchable PDF fidelity by storing OCR geometry and drawing hidden text closer to the true word positions on the scanned page.

Requirements:

- Capture Vision text observations with bounding boxes for each page.
- Preserve the normalized page text already used for search and previews.
- Add a persistence model for OCR geometry that can evolve without tightly coupling OCR to SwiftUI views.
- Convert Vision coordinates into PDF coordinates during searchable export.
- Keep export resilient when OCR data is partial or unavailable.

Prompt:

Implement OCR geometry alignment for Scan Man using Apple frameworks only. Extend the OCR pipeline to capture and store Vision text observations with bounding boxes per page, keep the current normalized page text for search, and update searchable PDF export so hidden/selectable text is placed using those bounding boxes rather than a single approximate text block. Preserve image-first rendering, offline behavior, testability, and graceful fallback when OCR geometry is unavailable.
