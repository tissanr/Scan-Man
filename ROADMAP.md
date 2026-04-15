# Roadmap

## Status

- Delivered: Phase 1
- Delivered: Phase 2
- Delivered: Phase 3
- Delivered: Phase 4
- Next: Phase 5
- Planned: Phase 6

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

- Keep Apple standard export options as the baseline export story.
- Evaluate export destinations by implementation complexity:
  - Lowest complexity: share sheet and Files-based export to any installed provider the system already exposes.
  - Medium complexity: saved export destinations or repeat-export workflows built on Apple document APIs.
  - Higher complexity: direct Nextcloud upload over WebDAV with account and error handling.
  - Highest complexity: Syncthing-specific export or sync flows, which likely need a companion process or a filesystem handoff design.
- Consider import from photos or PDFs.
- Explore annotations or lightweight editing.
- Decide which export paths belong in v1 versus post-v1.

## Phase 6

- Prepare the app for rollout through TestFlight and App Store distribution.
- Harden onboarding, permissions, error states, and empty states.
- Finalize app identity assets, privacy disclosures, export compliance answers, and release metadata.
- Expand release-oriented validation: device testing, migration checks, export/import smoke tests, and crash review.
- Define a staged rollout plan with internal beta, external beta, feedback triage, and release criteria.
