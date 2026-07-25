import Foundation

/// Shared JSON coders for everything that crosses the wire.
///
/// Configured once here so the app, the repositories and the `extract`
/// response all agree on how dates look.
enum JSONCoding {

    nonisolated static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseTimestamp(text) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "Not an ISO8601 timestamp: \(text)")
                )
            }
            return date
        }
        return decoder
    }()

    nonisolated static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(fullTimestamp))
        }
        return encoder
    }()

    /// Full date **and** time, with fractional seconds.
    ///
    /// Must be built with the initialiser. The builder methods
    /// (`.iso8601.time(...)`, `.year()`, and friends) compose a style from
    /// scratch rather than adding to the default, so `.iso8601.time(...)`
    /// silently yields a *time-only* format — which encodes every timestamp
    /// as 1 January 1970.
    ///
    /// `ISO8601FormatStyle` rather than `ISO8601DateFormatter` because the
    /// format style is `Sendable` and can safely live in a `static let`.
    nonisolated static let fullTimestamp = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Postgres hands back fractional seconds sometimes and not others, and
    /// writes the offset as `+00:00` where `Z` is also legal. Try each.
    nonisolated static func parseTimestamp(_ text: String) -> Date? {
        let styles: [Date.ISO8601FormatStyle] = [.iso8601, fullTimestamp]
        return styles.lazy.compactMap { try? $0.parse(text) }.first
    }
}

/// A calendar day with no time and no timezone — Postgres `date`.
///
/// Deliberately not a `Date`. A birth date or a start date shifted by a
/// timezone is the classic way to render "since 1 July" as "since 30 June".
nonisolated struct PlainDate: Codable, Hashable, Sendable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Not a yyyy-MM-dd date: \(text)")
            )
        }
        (year, month, day) = (parts[0], parts[1], parts[2])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// A time of day with no date — Postgres `time`, as used by
/// `medication.scheduled_times`.
///
/// C12 does arithmetic on these (separation windows, meal clustering), so they
/// stay minutes-since-midnight rather than pretending to be `Date`.
nonisolated struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// `"08:00"`, `"8:00"` or `"08:00:00"`. Nil for anything else.
    ///
    /// Shared with the `scheduled_times` write path, which parses times out of
    /// a `medication_update` before they ever reach Postgres — a bad time
    /// should fail the approval, not land in the column the scheduler reads.
    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces)
            .split(separator: ":")
            .compactMap { Int($0) }
        guard parts.count >= 2,
              (0 ... 23).contains(parts[0]),
              (0 ... 59).contains(parts[1])
        else { return nil }
        (hour, minute) = (parts[0], parts[1])
    }

    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = TimeOfDay(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Not a HH:mm[:ss] time: \(text)")
            )
        }
        self = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    /// Postgres `time` format.
    var description: String {
        String(format: "%02d:%02d:00", hour, minute)
    }

    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}
