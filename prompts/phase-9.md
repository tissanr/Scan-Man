# Phase 9 Prompt

Implement Phase 9 for Scan Man: Advanced Validation & Accessibility.

Scope:
- Implement Core Data migration verification.
- Automate accessibility audits in UI tests.
- Integrate code coverage monitoring.
- Add snapshot testing for OCR geometry overlays.

Requirements:
- Create a test suite that verifies data integrity across Core Data model versions.
- Use `XCUIApplication().performAccessibilityAudit()` in UI tests to catch accessibility regressions.
- Configure CI to report code coverage and fail if coverage drops below a defined threshold (e.g., 70%).
- Implement snapshot tests (using a lightweight approach or custom attachments) to verify the visual correctness of OCR overlays in `PagePreviewView`.

Acceptance criteria:
- Migration tests pass with sample data from older versions.
- UI tests fail if critical accessibility labels are missing.
- CI logs include a clear summary of code coverage per module.
- OCR overlays are visually verified against baseline snapshots.
