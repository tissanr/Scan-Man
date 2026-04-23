# Phase 8 Prompt

Implement Phase 8 for Scan Man: Developer Tooling & Documentation.

Scope:
- Standardize developer tasks with a Makefile.
- Implement Apple DocC for internal documentation.
- Refactor Dependency Injection for better testability.
- Automate screenshot capture for App Store preparation.

Requirements:
- Create a `Makefile` to unify commands like `make test`, `make build`, and `make lint`.
- Add DocC documentation to public methods in `Services` and `Domain` layers.
- Refactor `AppDependencies` to support easier swapping of mocks without relying on internal flags.
- Integrate `Fastlane Snap` or custom `XCUITest` attachments to automate screenshot generation for all supported device sizes.

Acceptance criteria:
- `Makefile` is functional and documented in `README.md`.
- Documentation can be built and viewed via Xcode's "Build Documentation".
- `AppDependencies` allows protocol-based injection of test doubles.
- Screenshots are automatically generated and saved to a predictable directory.
