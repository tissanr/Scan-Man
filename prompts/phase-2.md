# Phase 2 Prompt

Implement Phase 2 for Scan Man.

Scope:

- Add Vision OCR processing for scanned pages.
- Use OCR text for search, previews, title suggestion, text export, and searchable PDF export.
- Keep OCR work off the main UI path.

Requirements:

- Use `VNRecognizeTextRequest` with `.accurate`.
- Store normalized recognized text per page.
- Run OCR after scans are saved so the scan flow remains responsive.
- Search must match scan title and OCR text.
- Text export must preserve page order.
- Searchable PDF export must continue to work when OCR is missing by falling back cleanly.
- Keep the app Apple-framework-only and local-first.

Acceptance criteria:

- OCR text is persisted per page.
- Search returns scans based on OCR content.
- Suggested titles can come from the first meaningful OCR line.
- Text export returns page text in order.
- Searchable PDFs contain selectable text.
- Unit tests cover OCR mapping, search behavior, title suggestion, and export ordering.
