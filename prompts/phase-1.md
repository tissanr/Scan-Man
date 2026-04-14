# Phase 1 Prompt

Implement Phase 1 for Scan Man.

Scope:

- Replace the template app with a real Scan Man shell.
- Define Core Data entities for scans and pages.
- Build the home list, scan detail screen, and page browsing flow.
- Add VisionKit document capture, local persistence, and plain PDF export.
- Keep the app Apple-framework-only, local-first, and compatible with iOS 17+.

Requirements:

- Use SwiftUI for the UI and UIKit bridging only where Apple scanning APIs require it.
- Preserve page order for multi-page scans.
- Save all scan data locally with Core Data.
- Support browsing, deleting, renaming, and opening scans.
- Add plain image-based PDF export.
- Handle simulator camera unavailability gracefully.
- Avoid deprecated UIKit window APIs and fatal crashes in normal runtime paths.

Acceptance criteria:

- A user can scan a multi-page document on device.
- Pages are saved locally and visible in the library.
- A saved scan opens in detail and pages can be previewed.
- Image-only PDF export works.
- The app runs without CloudKit or push notifications.
