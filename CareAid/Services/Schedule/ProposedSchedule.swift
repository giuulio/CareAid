import Foundation

/// One day's medication, arranged around the caregiver.
nonisolated struct ProposedSchedule: Hashable, Sendable {
    var day: Date
    /// Handovers, in order. Each may carry several tablets.
    var slots: [ScheduleSlot]
    /// Never resolved automatically — each one becomes a question she can ask.
    var conflicts: [ScheduleConflict]
    /// When the caregiver is unavailable, shown so the proposal explains itself.
    var unavailable: [MinuteRange]
    /// When a paid carer is present.
    var helperWindows: [MinuteRange]

    /// True when nothing needed moving. Worth saying out loud rather than
    /// showing an empty "changes" list.
    var isUnchanged: Bool {
        slots.allSatisfy { $0.doses.allSatisfy { !$0.moved } }
    }

    var movedDoses: [PlannedDose] {
        slots.flatMap(\.doses).filter(\.moved)
    }
}

/// One handover: a time, and everything to be given at it.
nonisolated struct ScheduleSlot: Hashable, Sendable, Identifiable {
    var minute: Int
    var doses: [PlannedDose]
    var coverage: Coverage = .caregiver

    var id: Int { minute }
    var time: TimeOfDay { TimeOfDay(minutes: minute) }
}

/// One tablet at one time.
nonisolated struct PlannedDose: Hashable, Sendable, Identifiable {
    var medication: Medication
    /// The label rules that applied. Kept so the screen can quote them.
    var rules: [MedicationRule]
    /// Minutes since midnight, as prescribed.
    var prescribed: Int
    /// Minutes since midnight, as proposed.
    var proposed: Int
    var coverage: Coverage
    /// Set when this dose follows another medication's time by label rule.
    var tiedTo: String?

    var id: String { "\(medication.id)-\(prescribed)" }
    var moved: Bool { proposed != prescribed }
    var prescribedTime: TimeOfDay { TimeOfDay(minutes: prescribed) }
    var proposedTime: TimeOfDay { TimeOfDay(minutes: proposed) }
}

/// Who can actually hand the tablets over.
nonisolated enum Coverage: String, Hashable, Sendable {
    case caregiver
    case helper
    case nobody

    /// Written for the caregiver, in the second person.
    var plainDescription: String {
        switch self {
        case .caregiver: "You're free"
        case .helper: "Joy's there"
        case .nobody: "Nobody's there"
        }
    }

    var symbol: String {
        switch self {
        case .caregiver: "person.fill.checkmark"
        case .helper: "hands.and.sparkles.fill"
        case .nobody: "exclamationmark.triangle.fill"
        }
    }
}

/// Something the schedule cannot fix by itself.
///
/// Deliberately carries a `QuestionPayload` rather than a suggested change:
/// CLAUDE.md §2 rule 1 means the output of a conflict is always something to
/// ask a pharmacist or GP, never an instruction.
nonisolated struct ScheduleConflict: Hashable, Sendable, Identifiable {
    var medicationNames: [String]
    var headline: String
    var detail: String
    /// The exact label sentence, where a label is what raised this.
    var citation: String?
    var question: QuestionPayload

    var id: String { headline }
}

/// A span of a day, in minutes since midnight.
nonisolated struct MinuteRange: Hashable, Sendable {
    var start: Int
    var end: Int
    var label: String?

    init(start: Int, end: Int, label: String? = nil) {
        self.start = start
        self.end = end
        self.label = label
    }

    init(_ block: WorkHours.Block) {
        start = block.start.minutesSinceMidnight
        end = block.end.minutesSinceMidnight
        label = block.label
    }

    /// An EventKit busy block, clipped to the day it is being drawn on.
    init(_ busy: BusyBlock) {
        start = busy.startMinute
        end = busy.endMinute
        label = busy.title
    }

    func contains(_ minute: Int) -> Bool {
        minute >= start && minute < end
    }

    var displayRange: String {
        "\(TimeOfDay(minutes: start).display)–\(TimeOfDay(minutes: end).display)"
    }
}

/// A real diary event, reduced to what the scheduler needs.
///
/// `CalendarService` returns `Date`s; this converts them once, in London, so
/// the solver can stay in integer minutes and never touch a time zone.
nonisolated struct BusyBlock: Hashable, Sendable {
    var title: String?
    var startMinute: Int
    var endMinute: Int

    init(title: String?, startMinute: Int, endMinute: Int) {
        self.title = title
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    init(title: String?, start: Date, end: Date, on day: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let startOfDay = calendar.startOfDay(for: day)

        func minute(_ date: Date) -> Int {
            Int(date.timeIntervalSince(startOfDay) / 60)
        }
        self.title = title
        // Clipped: an event running past midnight should block the rest of
        // today, not wrap round to the small hours.
        startMinute = max(0, minute(start))
        endMinute = min(1440, minute(end))
    }
}

// `nonisolated` throughout: the solver is a pure function over integers and has
// no business hopping to the main actor. Default isolation is MainActor in this
// target, so it has to be said explicitly.

nonisolated extension TimeOfDay {
    init(minutes: Int) {
        self.init(hour: minutes / 60, minute: minutes % 60)
    }

    /// "08:00" — what she reads, not the Postgres form.
    var display: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

nonisolated extension Weekday {
    /// The weekday a date falls on, in London.
    init(_ date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        // Calendar counts Sunday as 1.
        let order: [Weekday] = [.sun, .mon, .tue, .wed, .thu, .fri, .sat]
        self = order[(calendar.component(.weekday, from: date) - 1) % 7]
    }
}

nonisolated extension Medication {
    /// Lowercased words from the name, for matching against a label sentence
    /// that spells the ingredient differently from the box.
    var nameTokens: [String] {
        let extras = name.lowercased().contains("careldopa") ? ["levodopa", "carbidopa"] : []
        return name
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count > 3 }
            + extras
    }
}
