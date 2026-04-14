# Phase 4 Prompt

Implement Phase 4 for Scan Man.

Scope:

- Improve simulator-friendly fallback behavior across the app.
- Expand UI test coverage for the core library flows.
- Allow lightweight editing of extracted OCR text per page where practical.
- Explore richer in-app OCR presentation using stored OCR geometry.
- Keep the app Apple-framework-only, local-first, and compatible with iOS 17+.

Requirements:

- Simulator behavior must be explicit and graceful when camera scanning is unavailable.
- UI tests should cover:
  - opening the home screen
  - starting the scan entry flow
  - opening a saved scan
  - searching scans
  - opening a page preview
  - editing extracted text for a page if implemented
- Add a practical per-page OCR text editing flow that updates persisted page text without breaking search, text export, or searchable PDF export.
- Use stored OCR geometry to improve the in-app reading experience where it adds value.
- Maintain graceful fallback when OCR geometry is missing or partial.
- Preserve existing page order, export behavior, and local persistence.

Acceptance criteria:

- The app behaves cleanly on simulator without camera support.
- Core UI tests exist and pass on a concrete simulator.
- Users can inspect and edit extracted text per page.
- Edited text persists and affects search and text export.
- Existing PDF export still works.
- OCR geometry-based UI enhancements do not break current detail and preview flows.
- Error handling remains non-crashing and user-visible.
