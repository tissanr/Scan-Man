# Scan Man

Scan Man is a local-first iOS document scanner built with Apple frameworks only.

## Features

- Multi-page scanning with VisionKit; import from Photos, PDF files, the share sheet, or the Files import folder.
- On-device text recognition (Vision) with search across titles, notes and page text.
- Searchable PDF export (invisible text aligned to each line), plain PDF and text export; A4, US Letter or fit-to-image pages.
- Page management: reorder, delete, rotate, crop with perspective correction, add pages.
- Per-page filters (Enhanced, Grayscale, Black & White), non-destructive.
- App lock with Face ID / Touch ID / passcode. No accounts, analytics or network access.

## Requirements

- Xcode 26 or newer (the project uses Swift 6 with default MainActor isolation)
- iOS 17+
- No third-party dependencies

## Build and Test

```bash
make build        # Build for the newest available iPhone simulator
make test         # Unit + UI tests with a coverage report
make screenshot   # App Store screenshots (attached to the test results)
```

Camera scanning is unavailable in the simulator; the app shows a message instead. UI tests use launch arguments such as `--ui-testing-seed-scan` and `--ui-testing-empty` (see `AppSeeder`).

To run on a device, select your signing team for the app and the share extension. The share extension needs the App Group `group.me.tissanr.OpenScannerRebuild`.

## Import Folder

`Files > On My iPhone > Scan Man > Scan Man Imports`. Images and PDFs placed there are imported the next time Scan Man becomes active and then removed from the folder. Images arriving together become one multi-page scan; each PDF becomes its own scan. Files shared through the share sheet are staged in the App Group and imported the same way.

## Export Decision

The system share sheet and Files are the export story for v1: they already cover AirDrop, Mail, Messages and every installed document provider. Direct Nextcloud/WebDAV upload, Syncthing-oriented auto-export and iCloud sync are planned after v1 (Phases 10–12 in `ROADMAP.md`).

## Documents

- `ROADMAP.md`: phases and status
- `SPEC.md`: product requirements and constraints
- `RELEASE.md`: App Store checklist and rollout plan
- `PRIVACY.md`: privacy policy
- `CLAUDE.md`: architecture and code standards
