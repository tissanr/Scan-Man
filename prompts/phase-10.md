# Phase 10 Prompt

Implement Phase 10 for Scan Man: iCloud Sync (CloudKit).

Scope:
- Enable seamless background synchronization of scans across Apple devices.
- Maintain a "local-first" architecture where the app works offline.

Requirements:
- Transition `PersistenceController` from `NSPersistentContainer` to `NSPersistentCloudKitContainer`.
- Update the Core Data model to support CloudKit (ensure all entities have required configurations).
- Implement an "iCloud Sync" toggle in the app settings (to be created).
- Handle CloudKit account status changes and initial sync edge cases.

Acceptance criteria:
- Scans created on one device appear on another using the same iCloud account.
- The app remains fully functional and performant even when iCloud is disabled or unavailable.
- Data integrity is preserved during the transition from local-only to CloudKit-backed storage.
