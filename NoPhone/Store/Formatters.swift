import Foundation

/// Duration formatting.
///
/// One rule throughout the product: never show seconds, and never show `0h`.
/// "1h 05m" for precision, "1h 5m" for prose, "45m" when there is no hour.
enum Fmt {

    /// Compact glanceable form used on bars, tiles and the lock screen.
    static func short(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        if minutes > 0 { return "\(minutes)m" }
        // Sub-minute reads as "<1m" rather than "0m", which looks like a bug.
        return total > 0 ? "<1m" : "0m"
    }

    /// Zero-padded variant for the big countdown, so digits don't jitter.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0
            ? String(format: "%d:%02d", hours, minutes)
            : "\(minutes)"
    }

    /// The unit shown beside `clock` — the two are always rendered together.
    static func clockUnit(_ seconds: TimeInterval) -> String {
        seconds >= 3600 ? "hours left" : "min left"
    }

    static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        switch (hours, minutes) {
        case (0, 0):            return "no time"
        case (0, let m):        return "\(m) minute\(m == 1 ? "" : "s")"
        case (let h, 0):        return "\(h) hour\(h == 1 ? "" : "s")"
        case (let h, let m):    return "\(h) hour\(h == 1 ? "" : "s") \(m) minute\(m == 1 ? "" : "s")"
        }
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    /// Greeting keyed to the hour — small touch, but it makes the home screen
    /// feel like it knows what part of the day you're in.
    static func greeting(for date: Date = .now) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default:      "Still up"
        }
    }
}
