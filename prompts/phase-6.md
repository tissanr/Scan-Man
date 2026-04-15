# Phase 6 Prompt

Implement Phase 6 for Scan Man.

Scope:

- Prepare the app for rollout through TestFlight and App Store distribution.
- Harden the delivered feature set instead of adding broad new scope.
- Close release-readiness gaps in UX, metadata, compliance, and validation.

Requirements:

- Preserve the local-first architecture and existing scan, OCR, search, editing, and export behavior.
- Audit and improve release-critical UX:
  - first-run and permission flows
  - empty states and error states
  - export and import reliability messaging
- Prepare release assets and configuration:
  - app icons and screenshots
  - version/build strategy
  - App Store description and keywords
  - privacy policy URL and App Privacy answers
  - export compliance answers
- Define a rollout plan with internal beta, external beta, crash and feedback review, and release criteria.
- Add or tighten tests that reduce rollout risk.

Acceptance criteria:

- The app is ready for internal TestFlight distribution with a clear release checklist.
- Release metadata and compliance gaps are identified or closed.
- Critical flows have explicit smoke-test coverage and known residual risks are documented.
