import Foundation

// Raw values mirror the `CHECK` constraints in CLAUDE.md §6 exactly. Anything
// the model invents fails here at decode, with a clear error, rather than
// surviving into an INSERT and dying on a Postgres constraint.

nonisolated enum CaptureSource: String, Codable, Sendable, CaseIterable {
    case voice, photo, text
}

nonisolated enum TimelineEventKind: String, Codable, Sendable, CaseIterable {
    case symptom, medication, incident, appointment, mood
    case careTask = "care_task"
    case admin

    /// Categorical only — which *kind* of thing happened, never how bad it is.
    var symbol: String {
        switch self {
        case .symptom: "waveform.path"
        case .medication: "pills"
        case .incident: "exclamationmark.triangle"
        case .appointment: "stethoscope"
        case .mood: "face.smiling"
        case .careTask: "hands.and.sparkles"
        case .admin: "tray.full"
        }
    }
}

nonisolated enum ArtifactKind: String, Codable, Sendable, CaseIterable {
    case task
    case calendarEvent = "calendar_event"
    case familyUpdate = "family_update"
    case question
    case timer
    case medicationUpdate = "medication_update"
}

nonisolated enum ArtifactStatus: String, Codable, Sendable, CaseIterable {
    case proposed, approved, dismissed, done, sent
}

nonisolated enum Channel: String, Codable, Sendable, CaseIterable {
    case whatsapp, sms, email
}

nonisolated enum ShareLevel: String, Codable, Sendable, CaseIterable {
    case headline, summary, full
}

/// How much attention an entry wants — an ordering hint drawn from the
/// caregiver's own words, not a clinical grade. Rule 1: we never rate anything
/// medically.
nonisolated enum Severity: Int, Codable, Sendable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
}

/// Which column on `medication` an approved `medication_update` writes.
///
/// `schedule` and `scheduledTimes` are two views of the same fact — the words
/// Sarah reads and the times the C12 scheduler does arithmetic on. A reported
/// change has to move both or the brief and the schedule drift apart silently,
/// which is exactly what CLAUDE.md §6 warns about, so the extraction prompt
/// emits one update for each.
nonisolated enum MedicationField: String, Codable, Sendable, CaseIterable {
    case dose
    case schedule
    case scheduledTimes = "scheduled_times"
    case active
    case quantityRemaining = "quantity_remaining"
}

nonisolated enum Trend: String, Codable, Sendable, CaseIterable {
    case improving, stable, worsening
}

nonisolated enum Weekday: String, Codable, Sendable, CaseIterable {
    case mon, tue, wed, thu, fri, sat, sun
}

/// Deliberately *not* a closed enum.
///
/// Flags are advisory and only drive UI prompts, so a type we have not seen
/// before should render as an unknown flag rather than fail the whole
/// response. Contrast with the kinds above, which are constrained by the
/// database and must stay closed.
nonisolated struct FlagType: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }

    static let ambiguousDate = FlagType(rawValue: "ambiguous_date")
    static let possibleEscalation = FlagType(rawValue: "possible_escalation")
}
