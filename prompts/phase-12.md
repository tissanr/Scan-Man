# Phase 12 Prompt

Implement Phase 12 for Scan Man: Auto-Export & Syncthing Helper.

Scope:
- Enable power users to automatically sync scans with external tools (like Syncthing) by mirroring local data to a visible filesystem directory.

Requirements:
- Implement a "Mirror to Files" feature that automatically saves a PDF version of every new or updated scan to a user-selected folder.
- Add a directory picker using `UIDocumentPickerViewController` to let users choose the destination folder (e.g., a folder synced by Mobius Sync).
- Maintain file naming consistency to allow external sync tools to detect changes.
- Ensure the background mirroring process is efficient and doesn't impact app performance.

Acceptance criteria:
- Every time a scan is saved or its title is updated, a corresponding PDF appears in the designated external folder.
- The feature can be toggled on/off in settings.
- Graceful handling of "Permissions Revoked" states for the external directory.
