import Foundation

/// Dates as a tired person reads them.
///
/// CLAUDE.md §8: "this morning", "yesterday evening" — never `24/07/2026`.
/// Everything is stored UTC and rendered Europe/London, so all of this goes
/// through `Config.displayTimeZone` rather than the device's locale.
nonisolated enum DisplayDate {

    /// "Today", "Yesterday", "Tomorrow", "Wednesday", "2 July", "2 July 2025".
    static func dayLabel(for date: Date, now: Date = .now) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0

        switch days {
        case 0: return "Today"
        case -1: return "Yesterday"
        case 1: return "Tomorrow"
        case -6 ... -2: return date.formatted(base.weekday(.wide))
        default:
            let sameYear = calendar.component(.year, from: date)
                == calendar.component(.year, from: now)
            return sameYear
                ? date.formatted(base.day().month(.wide))
                : date.formatted(base.day().month(.wide).year())
        }
    }

    /// "20:00"
    static func time(_ date: Date) -> String {
        date.formatted(base.hour().minute())
    }

    /// "yesterday evening", "this morning" — for prose, not list headers.
    static func partOfDay(_ date: Date, now: Date = .now) -> String {
        let hour = calendar.component(.hour, from: date)
        let part = switch hour {
        case 0 ..< 5: "night"
        case 5 ..< 12: "morning"
        case 12 ..< 17: "afternoon"
        case 17 ..< 21: "evening"
        default: "night"
        }
        let day = dayLabel(for: date, now: now).lowercased()
        return switch day {
        case "today": part == "night" ? "last night" : "this \(part)"
        case "yesterday": "yesterday \(part)"
        default: "\(day) \(part)"
        }
    }

    /// The day a timestamp belongs to, for grouping.
    static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    // MARK: - Internals

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    private static let base = Date.FormatStyle(
        locale: Locale(identifier: "en_GB"),
        timeZone: Config.displayTimeZone
    )
}
