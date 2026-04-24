# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
make build        # Build for iOS Simulator (iPhone 15)
make test         # Run full unit + UI test suite with code coverage
make clean        # Clean build artifacts
make doc          # Generate DocC documentation
make screenshot   # Capture marketing screenshots
make seed-data    # Launch simulator with seeded test data
```

CI runs on macOS 15 / Xcode 16 with `CODE_SIGNING_ALLOWED=NO`.

## Architecture

**MVVM, local-first, zero third-party dependencies** — all logic uses Apple frameworks only (SwiftUI, VisionKit, Vision, PDFKit, Core Data).

### Dependency Injection

`AppDependencies` (in `App/AppDependencies.swift`) is the single DI container. It has a `live()` factory for production and a testing variant. ViewModels receive their dependencies through this container — no singletons.

### Data Flow

```
Core Data (ScanEntity / ScanPageEntity)
    ↕ CoreDataScanRepository (implements ScanRepository protocol)
Domain models (ScanDocument / ScanPage — value types, Sendable)
    ↕ ViewModels (@Observable, @MainActor)
SwiftUI Views
```

All ViewModels are `@MainActor` and use `@Observable`. State flows unidirectionally: services mutate repository, repository emits updated models, ViewModels publish to views.

### Key Layers

| Path | Purpose |
|---|---|
| `OpenScannerRebuild/App/` | Entry point, DI container, root navigation |
| `OpenScannerRebuild/Features/` | Feature ViewModels + Views (Home, ScanDetail, Scan, Share) |
| `OpenScannerRebuild/Domain/Models/` | Pure value types: `ScanDocument`, `ScanPage`, `OCRTextObservation` |
| `OpenScannerRebuild/Data/CoreData/` | `PersistenceController`, `CoreDataScanRepository` |
| `OpenScannerRebuild/Services/` | OCR (`VisionOCRService`), PDF export, import, inbox |
| `OpenScannerRebuild/UI/Components/` | Reusable SwiftUI components |
| `ScanManShareExtension/` | Share extension — stages files in app-group inbox; main app processes on activation |

### Share Extension ↔ App Communication

App Group: `group.me.tissanr.OpenScannerRebuild`. The share extension writes files to a shared inbox; `ImportInboxService` processes them when the main app becomes active.

### Core Data Schema

`ScanEntity` (1-to-many) → `ScanPageEntity`. Pages ordered by `ScanPageEntity.order`. OCR geometry stored as JSON-encoded `[OCRTextObservation]` in `ocrLayoutData`. Cascade delete on scan removal.

## Testing

**Unit tests** use Swift Testing (`@Test` macro). Test doubles live in `OpenScannerRebuildTests/Support/TestDoubles.swift`; factories in `TestData.swift`.

**UI tests** use XCTest with launch arguments:
- `--ui-testing-empty` — fresh empty state
- `--ui-testing-seed-scan` — pre-seeded demo data

## Code Standards

- **Concurrency**: Swift 6 `async/await`, `Sendable`, `@MainActor` throughout — no DispatchQueue patterns.
- **Logging**: Use `AppLogger` categories (never `print`).
- **Errors**: Throw typed `AppError` values.
- **Docs**: Triple-slash `///` DocC comments on public APIs only.
- **Protocols**: Services expose protocol interfaces (e.g. `ScanRepository`, `OCRRecognizing`, `PDFExporting`) for testability.
