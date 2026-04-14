# Phase 5 Prompt

Implement Phase 5 for Scan Man.

Scope:

- Evaluate optional iCloud sync.
- Add import from photos and PDFs if the data model remains coherent.
- Explore annotations or lightweight markup without compromising the local-first baseline.

Requirements:

- Keep local-only behavior as a supported mode.
- Do not regress existing scan, OCR, search, text export, or PDF export behavior.
- Any sync design must be optional and isolated from the v1 local data path.
- Imported assets must map cleanly into the existing scan/page model.
- Annotation work must remain lightweight and not require third-party tooling.

Acceptance criteria:

- Optional sync/import work is additive and does not block offline use.
- Imported scans behave like camera-created scans in library, detail, search, and export.
- Any annotation feature remains minimal and does not destabilize the export pipeline.
