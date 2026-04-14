# Roadmap

## Status

- Delivered: Phase 1
- Delivered: Phase 2
- Delivered: Phase 3
- Delivered: Phase 4
- Next: Phase 5

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
- Status: delivered

## Phase 5

- Evaluate optional iCloud sync.
- Consider import from photos or PDFs.
- Explore annotations or lightweight editing.
