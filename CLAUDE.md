# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
make build        # Build for the newest available iPhone simulator
make test         # Run unit + UI tests, then print a coverage report
make clean        # Clean build artifacts
make doc          # Generate DocC documentation
make screenshot   # Capture marketing screenshots (ScreenshotTests)
make seed-data    # Launch the booted simulator with seeded test data
```

Toolchain: **Xcode 26**, Swift 6 language mode. CI (`.github/workflows/ci.yml`) runs on `macos-26` with the newest Xcode 26 and `CODE_SIGNING_ALLOWED=NO`, uploads the result bundle and recorded snapshots, and checks coverage with `scripts/check-coverage.py`.

## Architecture

**MVVM, local-first, zero third-party dependencies**: Apple frameworks only (SwiftUI, VisionKit, Vision, Core Image, PDFKit/Core Graphics, Core Data, LocalAuthentication).

### Concurrency model

The app target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency:

- Views, view models and app-level coordinators are main-actor (the default).
- Domain models, services, protocols and Core Data classes are explicitly `nonisolated` and `Sendable`.
- Heavy work (OCR, image processing, PDF rendering/writing, PDF import) runs in `@concurrent` static helpers. Protocol witnesses stay plain `async` and forward to those helpers.
- No `DispatchQueue`.

### Dependency Injection

`AppDependencies` (`App/AppDependencies.swift`) is the single container. `live()` uses the on-disk store; `inMemory()` uses a throwaway store. It also creates view models (`makeHomeViewModel()`, `makeScanDetailViewModel(scanID:)`) and runs launch work (`prepareForLaunch()`). No singletons.

### Data Flow

```
Core Data (ScanEntity / ScanPageEntity, model v2)
    ↕ CoreDataScanRepository (ScanRepository: targeted, race-free mutations)
Domain models (ScanSummary for lists, ScanDocument / ScanPage for detail)
    ↕ ViewModels (@Observable, main actor)
SwiftUI Views
```

- The home list uses `ScanSummary` (title, page count, preview, cover thumbnail, normalized search text), stored as derived fields on `ScanEntity`. It never loads page images.
- Mutations are targeted (`updateTitle`, `applyOCRResults`, `deletePage`, `replacePageImage`, ...) so background OCR and user edits never overwrite each other. Only use `save(scan:)` for new scans.
- After a write, call `LibraryEvents.libraryDidChange()`; screens observe `revision` and reload.
- `OCRCoordinator` runs OCR for new or changed pages and merges the results through `applyOCRResults` (keeps user-entered text, only replaces placeholder titles, ignores deleted scans).
- Page images: `imageData` is the upright original; filters go in `processedImageData`; `displayImageData` is what's shown and exported. OCR always reads the original.

### Key Layers

| Path | Purpose |
|---|---|
| `OpenScannerRebuild/App/` | Entry point, DI, root view, settings, app lock, OCR coordinator, UI-testing seeder |
| `OpenScannerRebuild/Features/` | Home, ScanDetail (incl. crop), Scan, Share, Settings, Onboarding |
| `OpenScannerRebuild/Domain/Models/` | `ScanDocument`, `ScanPage`, `ScanSummary`, export/import options |
| `OpenScannerRebuild/Data/CoreData/` | `PersistenceController`, hand-written managed objects, `CoreDataScanRepository` |
| `OpenScannerRebuild/Services/` | OCR (Vision), Imaging (Core Image), PDF export, import, import inbox |
| `OpenScannerRebuild/UI/Components/` | Reusable SwiftUI components |
| `ScanManShareExtension/` | Share extension: stages files in the App Group inbox; the app imports them on activation |

### Core Data

- Versioned model (`OpenScannerRebuild.xcdatamodeld`): v1 is the original schema, **v2 is current** (summary fields, external binary storage, `processedImageData`, `enhancement`). Migration is lightweight; `rebuildDerivedFieldsIfNeeded()` backfills summary fields at launch.
- Codegen is off: `ManagedObjects.swift` defines the classes. Insert with `ScanEntity.insert(into:)`, not `init(context:)`.
- The model is loaded once (`PersistenceController.sharedModel`).
- **Schema changes**: add a new model version, never edit an existing one, and extend `MigrationTests`.

### Share Extension ↔ App

App Group `group.me.tissanr.OpenScannerRebuild`. The extension copies files into `Shared Import Inbox` under a hidden staging name, then renames them; `ImportInboxService` skips hidden files.

## Testing

- **Unit tests** use Swift Testing. Doubles are in `OpenScannerRebuildTests/Support/TestDoubles.swift` (`StubScanRepository`, `StubScanImporter`, `StubImportInbox`, `StubOCRProcessor`, `TestEnvironment`), factories in `TestData.swift`. Repository, migration and export tests use the real Core Data stack with `PersistenceController(inMemory: true)`.
- **Snapshot tests** (`SnapshotTests.swift`) compare against PNGs in `OpenScannerRebuildTests/__Snapshots__`. A missing baseline is recorded and the test fails once; commit the PNG. CI uploads the folder as the `snapshots` artifact.
- **UI tests** use XCTest with launch arguments: `--ui-testing-empty`, `--ui-testing-seed-scan`, `--ui-testing-onboarding`. Any `--ui-testing*` argument skips onboarding and disables app lock.

## Code Standards

- **Concurrency**: Swift 6, `async/await`, `Sendable`; see the concurrency model above.
- **Logging**: `Logger` categories from `Utilities/AppLogger.swift` (never `print`). Mark user content `privacy: .private`.
- **Errors**: services throw `AppError` (or a domain error such as `ScanImportError`); view models turn errors into messages with `AppError.wrap`.
- **Docs**: `///` DocC comments on public APIs only.
- **Protocols**: services expose protocols (`ScanRepository`, `OCRRecognizing`, `ImageProcessing`, `PDFExporting`, `ScanImporting`, ...) for testability.
- **User-facing name**: "Scan Man" (the target is still called `OpenScannerRebuild`).
