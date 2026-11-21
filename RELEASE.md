# Release Guide

How Scan Man goes from `main` to the App Store. Items marked **(manual)** cannot be done in code.

## 1. Before the first build

- [ ] **(manual)** App icon: add a 1024×1024 PNG (plus dark and tinted variants) to `Assets.xcassets/AppIcon.appiconset`. The catalog currently has no image, and App Store Connect rejects builds without an icon.
- [ ] **(manual)** In App Store Connect, create the app with bundle ID `me.tissanr.OpenScannerRebuild` and enable the App Group `group.me.tissanr.OpenScannerRebuild` for both the app and the share extension (`me.tissanr.OpenScannerRebuild.ShareExtension`).
- [ ] **(manual)** Host `PRIVACY.md` (for example with GitHub Pages) and note the URL.
- [ ] Bump `MARKETING_VERSION` (1.0) and `CURRENT_PROJECT_VERSION` for every upload.

## 2. App Store Connect answers

**App Privacy** ("nutrition label"): *Data Not Collected*. Scan Man has no accounts, analytics, ads or network code; scans are stored only on the device and leave it only when the user shares them.

**Export compliance**: `ITSAppUsesNonExemptEncryption = NO` is set in the Info.plist. The app uses no encryption beyond what iOS provides (data protection), so no documentation is needed.

**Privacy manifests**: `OpenScannerRebuild/PrivacyInfo.xcprivacy` declares UserDefaults access (reason `CA92.1`, app-only settings) and no tracking. The share extension has its own empty manifest.

**Age rating**: 4+ (no objectionable content, no web access, no user-generated content shared with others).

**Category**: Productivity (secondary: Business).

## 3. Store listing draft

- **Name**: Scan Man
- **Subtitle**: Private document scanner
- **Promotional text**: Scan, search and share documents. Everything stays on your iPhone.
- **Description**:

  Scan Man turns paper into searchable PDFs, privately.

  • Scan multi-page documents with automatic edge detection
  • Text recognition on your device: search every word in every scan
  • Export searchable PDFs, plain PDFs or text
  • Import photos and PDFs, or share them to Scan Man from any app
  • Reorder, rotate, crop and enhance pages
  • A4, US Letter or fit-to-page PDFs
  • Lock the app with Face ID

  No account. No cloud. No tracking. Your documents never leave your device unless you share them.

- **Keywords**: scanner,pdf,ocr,document,scan,receipt,invoice,searchable,private,offline
- **Screenshots**: run `make screenshot`; the images are attached to the test results. Capture on a 6.9" iPhone (required) and 13" iPad (if shipping on iPad).

## 4. Validation before each upload

- [ ] CI is green on `main` (unit, UI, accessibility, snapshot, migration tests; coverage threshold).
- [ ] **(manual)** On a physical iPhone: scan a 10+ page document, rotate/crop/filter a page, export a searchable PDF and search it in Files, share a PDF and a photo into Scan Man from Files and Photos, use the import folder, enable and use Face ID lock.
- [ ] **(manual)** Upgrade test: install the previous TestFlight build, create scans, install the new build, confirm all scans, text and search still work.
- [ ] **(manual)** Low storage and a 100-page PDF import complete without crashing.
- [ ] **(manual)** VoiceOver pass over home, detail, page and settings screens; largest Dynamic Type size.

## 5. Staged rollout

1. **Internal TestFlight** (team, ~1 week). Exit: no crashes in Xcode Organizer, all checklist items above pass.
2. **External TestFlight** (20–50 testers with real paperwork: receipts, contracts, multi-page letters, ~2 weeks). Collect feedback via TestFlight screenshots. Exit: crash-free sessions ≥ 99.5%, no data-loss reports, no open P1 issues.
3. **App Store release** with *phased release* enabled (7-day rollout). Pause the rollout on any data-loss report or crash spike.

**Triage**: P1 = data loss, crash on launch, can't scan or export → fix before continuing the rollout. P2 = a feature doesn't work in some cases → next build. P3 = polish → backlog.

**Go/no-go** for each stage: CI green, checklist done, no open P1, crash-free rate meets the target, release notes written.
