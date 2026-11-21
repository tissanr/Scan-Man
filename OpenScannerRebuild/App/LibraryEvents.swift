import Foundation
import Observation

/// Signals that stored scans changed, so every screen showing them can reload.
@MainActor
@Observable
final class LibraryEvents {
    private(set) var revision = 0

    func libraryDidChange() {
        revision &+= 1
    }
}
