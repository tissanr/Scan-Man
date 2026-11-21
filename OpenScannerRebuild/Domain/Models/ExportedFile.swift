import Foundation

nonisolated struct ExportedFile: Equatable, Sendable {
    let url: URL
    let filename: String
}
