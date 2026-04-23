# Phase 7 Prompt

Implement Phase 7 for Scan Man: Core Infrastructure & Performance.

Scope:
- Automate testing with CI/CD.
- Implement structured logging and error management.
- Establish performance benchmarks for critical paths.

Requirements:
- Create a GitHub Actions workflow to run unit and UI tests on every PR.
- Introduce a centralized logging utility using Apple's `Logger` (OSLog).
- Categorize logs by subsystem (persistence, OCR, PDF, etc.).
- Define a unified `AppError` type for consistent error handling.
- Add `XCTMetric` performance tests for Core Data fetches and PDF exports.

Acceptance criteria:
- `.github/workflows/ci.yml` exists and triggers on push/pull requests.
- `AppLogger.swift` is implemented and available project-wide.
- Performance tests in `PerformanceTests.swift` pass and provide baseline metrics.
- The project follows a "zero-warning" build policy in CI.
