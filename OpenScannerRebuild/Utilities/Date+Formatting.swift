import Foundation

extension Date {
    var scanTimestampLabel: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}
