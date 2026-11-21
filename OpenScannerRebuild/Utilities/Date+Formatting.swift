import Foundation

nonisolated extension Date {
    var scanTimestampLabel: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}
