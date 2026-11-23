# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Scan Man** is a local-first iOS document scanner (iOS 17+). Internal names still use the original
project name `OpenScannerRebuild` (targets, module, Core Data model, bundle ID `me.tissanr.OpenScannerRebuild`);
everything user-facing says "Scan Man". Product scope lives in `SPEC.md`, phase status in `ROADMAP.md`.

## Build & Test Commands

```bash
make build        # Build for the newest available iPhone simulator
make test         # Full unit + UI test suite with code coverage (slow, ~10 min)
make unit-test    # Unit tests only — use this for quick verification
make ui-test      # UI tests only
make doc          # Generate DocC documentation
make screenshot   # Run the marketing screenshot UI test
```

The simulator is picked by `scripts/simulator-destination.sh`; override with
`make test DESTINATION='platform=iOS Simulator,name=iPhone 17'`.
Run a single test with `xcodebuild test ... -only-testing:OpenScannerRebuildTests/ScanDomainTests/<testName>`.

CI (`.github/workflows/ci.yml`) runs the full suite on `macos-26` with `CODE_SIGNING_ALLOWED=NO`.
Xcode 26 or newer is required (see Concurrency below).

## Architecture

**MVVM, local-first, zero third-party dependencies** — Apple frameworks only (SwiftUI, VisionKit, Vision, PDFKit, Core Data).

### Dependency Injection

`AppDependencies` (`App/AppDependencies.swift`) is the single DI container, built via `AppDependencies.live()`.
`RootView` owns the `HomeViewModel` and creates a `ScanDetailViewModel` per navigation. Tests don't use the
container — they construct ViewModels directly with stubs from `OpenScannerRebuildTests/Support/TestDoubles.swift`.

### Data Flow

```
Core Data (ScanEntity / ScanPageEntity)
    ↕ CoreDataScanRepository (implements ScanRepository; all work in background contexts)
Domain models (ScanDocument / ScanPage — Sendable value types)
    ↕ ViewModels (ObservableObject + @Published, @MainActor)
SwiftUI Views (@StateObject)
```

The repository does not publish changes. ViewModels fetch explicitly and keep their own copy:
- After an import, `HomeViewModel` saves the scan, then runs OCR in a background `Task` and merges the result
  into the *currently stored* scan (the user may have renamed or deleted it meanwhile).
- Edits in the detail screen are pushed back to the library list via the `onScanUpdated` callback.

### Key Layers

| Path | Purpose |
|---|---|
| `OpenScannerRebuild/App/` | Entry point, DI container, root view, UI-test seeding (`AppSeeder`) |
| `OpenScannerRebuild/Features/` | Feature ViewModels + Views (Home, ScanDetail, Scan, Share) |
| `OpenScannerRebuild/Domain/Models/` | `ScanDocument`, `ScanPage`, `OCRTextObservation`, `ExportedFile` |
| `OpenScannerRebuild/Data/CoreData/` | `PersistenceController`, `CoreDataScanRepository` |
| `OpenScannerRebuild/Services/` | OCR (`VisionOCRService`, `ScanOCRProcessor`), PDF/text export, import, inbox |
| `OpenScannerRebuild/UI/Components/` | Reusable SwiftUI components |
| `ScanManShareExtension/` | Share extension — stages files in the app-group inbox; main app imports on activation |
| `prompts/` | Original per-phase implementation prompts (historical) |

### Share Extension ↔ App

App Group `group.me.tissanr.OpenScannerRebuild`. The extension copies shared images/PDFs into
`Shared Import Inbox` in the group container. `ImportInboxService` scans that folder plus the Files-visible
`Documents/Scan Man Imports` whenever the app becomes active; files are deleted after a successful import.

### Core Data Schema

`ScanEntity` (1-to-many, cascade) → `ScanPageEntity`, ordered by `order`. Page images and thumbnails are
stored as binary attributes; OCR geometry is JSON-encoded `[OCRTextObservation]` in `ocrLayoutData`
(Vision-normalized coordinates, bottom-left origin). The model is **not versioned** yet — any schema change
must add a new model version with a lightweight-migration path, not edit the existing one.

### Searchable PDF

`PDFExportService` draws the page image and, in `.searchable` mode, an invisible text layer
(`CGContext.setTextDrawingMode(.invisible)`). Lines are placed on their OCR boxes while the geometry still
matches `recognizedText`; once the user edits the text, the edited text is embedded as a block instead.

## Code Standards

- **Concurrency**: The app target uses Swift 5 language mode with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  and approachable concurrency. Every type is `@MainActor` unless marked otherwise — CPU-heavy work
  (OCR, rendering) must be `nonisolated` + `@concurrent` or it will block the UI. Use `async/await`, no `DispatchQueue`.
  The test and extension targets do *not* default to MainActor; test suites touching ViewModels are `@MainActor`.
- **Logging**: `AppLogger.swift` defines `Logger` categories (`.persistence`, `.ocr`, `.pdf`, `.ui`, `.lifecycle`). Use them, never `print`.
- **Errors**: Services throw typed `LocalizedError`s (`ScanImportError`, `OCRServiceError`); ViewModels map
  them to user-facing messages in `activeErrorMessage`. `AppError` (in `AppLogger.swift`) exists but is not adopted yet.
- **User-facing strings** say "Scan Man", never "Open Scanner".
- **Docs**: `///` DocC comments on protocols and non-obvious APIs.
- **Protocols**: Services sit behind protocols (`ScanRepository`, `OCRRecognizing`, `PDFExporting`,
  `ScanImporting`, `ImportInboxManaging`, …) so they can be stubbed.

## Testing

- **Unit tests** (`OpenScannerRebuildTests`) use Swift Testing (`@Test`); performance and migration checks use XCTest.
  Factories are in `Support/TestData.swift`. `StubScanRepository` keeps scans in memory and records `savedScans`.
- **UI tests** (`OpenScannerRebuildUITests`) use XCTest with launch arguments:
  - `--ui-testing-empty` — wipes the store for a fresh empty state
  - `--ui-testing-seed-scan` — seeds one "Seeded Invoice" scan
- Camera scanning is unavailable in the simulator; the app shows a fallback alert instead.
- UI test classes force portrait in `setUp` (the launch tests rotate the simulator). Scroll to elements
  below the fold before tapping, and don't assert on the software keyboard — the simulator often uses a hardware keyboard.
