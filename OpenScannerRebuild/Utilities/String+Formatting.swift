import Foundation

extension String {
    var normalizedOCRText: String {
        let lines = components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    var normalizedPreview: String {
        let normalized = normalizedOCRText.replacingOccurrences(of: "\n", with: " ")
        guard normalized.count > 120 else {
            return normalized
        }

        let index = normalized.index(normalized.startIndex, offsetBy: 117)
        return String(normalized[..<index]) + "..."
    }
}
