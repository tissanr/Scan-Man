import Foundation

extension Array where Element == ScanPage {
    var previewText: String {
        sorted(by: { $0.order < $1.order })
            .map(\.previewText)
            .first(where: { !$0.isEmpty }) ?? ""
    }
}
