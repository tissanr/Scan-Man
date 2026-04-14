# Phase 3 Prompt

Implement Phase 3 for Scan Man.

Scope:

- Extend the OCR pipeline to capture Vision text observations with bounding boxes per page, not just normalized full-page text.
- Persist OCR geometry in a way that is testable and easy to evolve.
- Update searchable PDF export so hidden/selectable text is drawn using OCR bounding boxes and scaled into the correct PDF coordinates.
- Preserve existing image-first PDF rendering and page order.
- Keep the app Apple-framework-only and local-first.

Requirements:

- Store OCR geometry alongside normalized page text.
- Search and previews must keep using normalized page text.
- Searchable export must use bounding boxes when available.
- If OCR geometry is missing, searchable export must fall back cleanly to current behavior.
- Do not add CloudKit, third-party dependencies, or non-Apple frameworks.

Acceptance criteria:

- Exported searchable PDFs have materially better text alignment against the source scan.
- Text selection and search work in Preview and Files with closer word placement than the page-wide approximation.
- Existing image-only PDF export still works.
- OCR failures remain non-fatal and user-visible.
- Tests cover OCR geometry persistence, coordinate conversion, and searchable PDF placement behavior.
