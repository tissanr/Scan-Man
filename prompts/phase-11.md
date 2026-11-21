# Phase 11 Prompt

Implement Phase 11 for Scan Man: WebDAV & Nextcloud Export.

Scope:
- Allow users to export scans directly to private cloud storage using the WebDAV protocol.

Requirements:
- Implement a custom `WebDAVClient` using `URLSession` (adhering to the Apple-frameworks-only mandate).
- Add support for common WebDAV verbs: `PUT` (upload), `PROPFIND` (directory check), and `MKCOL` (create directory).
- Create a "Cloud Storage" configuration screen for users to enter their URL, username, and password/app-token.
- Add an "Export to Cloud" action in the scan detail and share menus.

Acceptance criteria:
- Users can successfully upload a PDF scan to a Nextcloud or standard WebDAV instance.
- Connection details are securely stored in the Keychain.
- Clear error reporting is provided for network or authentication failures.
