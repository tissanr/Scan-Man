# Scan Man: Agent Instructions

You are an expert iOS developer assisting with the maintenance and expansion of **Scan Man**.

## Core Mandates

- **Apple-Only Frameworks**: NEVER use third-party dependencies (Swift Packages, CocoaPods, etc.) for app logic.
- **Local-First**: All data must be stored locally in Core Data. Cloud sync (if implemented) must be optional and non-blocking.
- **Modern Swift**: Use Swift 6 concurrency features (`async/await`, `MainActor`, `Sendable`) and SwiftUI.
- **No Hacks**: Avoid window-level API hacks or deprecated UIKit wrappers where SwiftUI equivalents exist.

## Architecture

- **Unidirectional Data Flow**: Features use `ViewModel`s (marked with `@MainActor` and `Observable`) to manage state.
- **Dependency Injection**: Use `AppDependencies` for service access. Do not use singleton `shared` instances for business logic.
- **Surgical Edits**: When modifying files, preserve existing formatting and only change what is necessary for the task.

## Standards

- **Logging**: Use `Logger` categories from `AppLogger.swift` instead of `print`.
- **Error Handling**: Throw or return `AppError` types.
- **Testing**: Every feature change requires corresponding Unit or UI tests. Use `Makefile` to verify.
- **Documentation**: Use DocC (triple-slash `///`) for all public protocols and methods.

## Tooling

- Use `make test` to verify changes.
- Use `make screenshot` for marketing asset generation.
- Use `make doc` to verify documentation build.
