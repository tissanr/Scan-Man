# Phase 5 Prompt

Implement Phase 5 for Scan Man.

Scope:

- Evaluate optional iCloud sync.
- Keep Apple standard export paths as the default export strategy.
- Evaluate export targets and rank them by complexity:
  - share sheet and Files providers already exposed by iOS
  - repeated export conveniences such as remembered destinations
  - direct Nextcloud upload
  - Syncthing-specific export or sync
- Add import from photos and PDFs if the data model remains coherent.
- Explore annotations or lightweight markup without compromising the local-first baseline.

Requirements:

- Keep local-only behavior as a supported mode.
- Do not regress existing scan, OCR, search, text export, or PDF export behavior.
- Any sync design must be optional and isolated from the v1 local data path.
- Treat Apple-native export via share sheet and document picker as the baseline, lowest-complexity option.
- Direct provider-specific export must justify itself against the system export flows on UX value, not just technical possibility.
- If evaluating direct Nextcloud export, include account model, authentication, upload progress, retries, and conflict semantics.
- If evaluating Syncthing export, explicitly address iOS sandbox limits, background execution limits, and whether the design depends on a companion app or Files handoff.
- Imported assets must map cleanly into the existing scan/page model.
- Annotation work must remain lightweight and not require third-party tooling.

Acceptance criteria:

- Optional sync/import work is additive and does not block offline use.
- Export evaluation clearly distinguishes what belongs in v1, what belongs later, and why.
- Imported scans behave like camera-created scans in library, detail, search, and export.
- Any annotation feature remains minimal and does not destabilize the export pipeline.
