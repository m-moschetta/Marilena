import Foundation

/// Utilities to encode/decode a stable completion state into event notes/description
/// Format example: [MLN:completed=1;completedAt=2025-08-28T10:32:00Z]
struct CalendarCompletionMetadata {
    struct State {
        let isCompleted: Bool
        let completedAt: Date?
    }

    private static let tagPrefix = "[MLN:"
    private static let tagSuffix = "]"

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        return f
    }()

    /// Parse completion state from a notes/description string
    static func parse(from notes: String?) -> State? {
        guard let notes, let range = rangeOfTag(in: notes) else { return nil }
        let tag = String(notes[range])
        // Remove prefix/suffix
        let inner = tag
            .dropFirst(tagPrefix.count)
            .dropLast(tagSuffix.count)
        // inner now like: completed=1;completedAt=...
        let pairs = inner
            .split(separator: ";")
            .map { $0.split(separator: "=") }
            .reduce(into: [String: String]()) { dict, kv in
                guard kv.count == 2 else { return }
                dict[String(kv[0]).trimmingCharacters(in: .whitespaces)] = String(kv[1]).trimmingCharacters(in: .whitespaces)
            }

        let completed = (pairs["completed"].map { $0 == "1" || $0.lowercased() == "true" }) ?? false
        let completedAt: Date?
        if let s = pairs["completedAt"], let d = isoFormatter.date(from: s) { completedAt = d } else { completedAt = nil }
        return State(isCompleted: completed, completedAt: completedAt)
    }

    /// Produce an updated notes string with the completion state written or updated.
    static func write(to notes: String?, completed: Bool, completedAt: Date = Date()) -> String {
        let payload = makePayload(completed: completed, completedAt: completedAt)
        let current = notes ?? ""
        if let range = rangeOfTag(in: current) {
            var s = current
            s.replaceSubrange(range, with: payload)
            return s
        } else {
            if current.isEmpty { return payload }
            // Append on a new line to avoid interfering with existing user notes
            return current + "\n" + payload
        }
    }

    /// Remove the metadata tag from a notes string (if present)
    static func remove(from notes: String?) -> String {
        let current = notes ?? ""
        guard let range = rangeOfTag(in: current) else { return current }
        var s = current
        s.removeSubrange(range)
        // Trim trailing newlines left by removal
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Internals

    private static func makePayload(completed: Bool, completedAt: Date) -> String {
        let completedVal = completed ? "1" : "0"
        let when = isoFormatter.string(from: completedAt)
        let body = "completed=\(completedVal);completedAt=\(when)"
        return tagPrefix + body + tagSuffix
    }

    /// Find the range of our MLN tag inside the string (as integer offsets)
    private static func rangeOfTag(in s: String) -> Range<String.Index>? {
        guard let startRange = s.range(of: tagPrefix) else { return nil }
        guard let endRange = s[startRange.upperBound...].range(of: tagSuffix) else { return nil }
        return startRange.lowerBound..<endRange.upperBound
    }
}
