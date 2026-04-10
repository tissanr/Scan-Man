# Roadmap

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

### Phase 3 Prompt

Implement OCR geometry alignment for Scan Man.

Scope:

- Keep the app Apple-framework-only and local-first.
- Extend the OCR pipeline to capture Vision text observations with bounding boxes per page, not just normalized full-page text.
- Persist OCR geometry in a way that is testable and easy to evolve.
- Update searchable PDF export so hidden/selectable text is drawn using the OCR bounding boxes and scaled into the correct PDF coordinates.
- Preserve existing image-first PDF rendering and page order.
- If OCR geometry is missing, searchable export must still fall back cleanly to the current image-only or text-only behavior.
- Do not add CloudKit, third-party dependencies, or non-Apple frameworks.

Acceptance criteria:

- Exported searchable PDFs have materially better text alignment against the source scan.
- Text selection/search works in Preview/Files with closer word placement than the current whole-page approximation.
- Existing image-only PDF export still works.
- OCR failures remain non-fatal and user-visible.
- Unit tests cover coordinate conversion and searchable PDF text placement behavior.

## Phase 4

- Improve simulator-friendly fallback handling and expand UI tests for core library flows.
- Allow lightweight editing of extracted page text where practical.
- Explore richer in-app OCR presentation using stored geometry.

## Phase 5

- Evaluate optional iCloud sync.
- Consider import from photos or PDFs.
- Explore annotations or lightweight editing.
