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
