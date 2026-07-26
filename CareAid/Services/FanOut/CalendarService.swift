import EventKit
import Foundation

/// Writes an approved `calendar_event` into her real diary.
///
/// Asks for **full** access rather than write-only: C12 needs to read her busy
/// blocks to schedule medication around her actual day, and asking twice is
/// worse than asking once.
struct CalendarService {
    private let store = EKEventStore()

    enum CalendarError: LocalizedError {
        case accessDenied
        case noDefaultCalendar

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                "CareAid needs access to your calendar. Settings › CareAid › Calendars."
            case .noDefaultCalendar:
                "No calendar is set up on this phone to add events to."
            }
        }
    }

    func requestAccess() async throws {
        guard try await store.requestFullAccessToEvents() else {
            throw CalendarError.accessDenied
        }
    }

    /// Writes the event, or rewrites the one this artifact wrote last time.
    ///
    /// Keyed on `artifact.id`, the same way `ReminderService` keys its
    /// notification request. Approving can fail *after* the diary write — a
    /// dropped connection on the status PATCH leaves a "Try again" button that
    /// re-runs this method — and without a key that second tap would put a
    /// second consultant's appointment in her real calendar.
    @discardableResult
    func add(_ payload: CalendarEventPayload, artifactID: UUID) async throws -> String {
        try await requestAccess()

        let event = try existingEvent(for: artifactID) ?? newEvent()
        event.title = payload.title
        event.startDate = payload.startsAt
        // An appointment with no stated end still needs one; an hour is a
        // reasonable guess for a consultation and she can edit it.
        event.endDate = payload.endsAt ?? payload.startsAt.addingTimeInterval(3600)
        event.location = payload.location
        event.notes = payload.notes

        // Cleared first: on a rewrite these would otherwise stack up alongside
        // the ones already on the event.
        event.alarms = nil
        for minutes in payload.remindersMin {
            event.addAlarm(EKAlarm(relativeOffset: -Double(minutes) * 60))
        }

        try store.save(event, span: .thisEvent, commit: true)
        Self.remember(event.eventIdentifier, for: artifactID)
        return event.eventIdentifier
    }

    /// A phone with no *default* calendar usually still has a writable one —
    /// a fresh device, or an account whose default was never set. Falling back
    /// to the first one she can write to is better than refusing the diary
    /// entry the whole demo turns on.
    private func newEvent() throws -> EKEvent {
        let calendar = store.defaultCalendarForNewEvents
            ?? store.calendars(for: .event).first(where: \.allowsContentModifications)
        guard let calendar else { throw CalendarError.noDefaultCalendar }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        return event
    }

    /// Nil if we've never written this artifact, or if she has since deleted
    /// the event by hand — in which case writing a fresh one is right.
    private func existingEvent(for artifactID: UUID) -> EKEvent? {
        guard let identifier = Self.rememberedIdentifier(for: artifactID) else { return nil }
        return store.event(withIdentifier: identifier)
    }

    // MARK: - Artifact → event identity

    // UserDefaults rather than a column: the mapping is local to this phone,
    // and `artifact` has nowhere in §6 to put an EventKit identifier.

    private static func defaultsKey(_ artifactID: UUID) -> String {
        "careaid.calendar.event.\(artifactID.uuidString)"
    }

    private static func rememberedIdentifier(for artifactID: UUID) -> String? {
        UserDefaults.standard.string(forKey: defaultsKey(artifactID))
    }

    private static func remember(_ identifier: String?, for artifactID: UUID) {
        guard let identifier else { return }
        UserDefaults.standard.set(identifier, forKey: defaultsKey(artifactID))
    }

    /// C12 reads these to find the gaps where she can actually hand over pills.
    func busyBlocks(from start: Date, to end: Date) async throws -> [(start: Date, end: Date)] {
        try await requestAccess()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.availability != .free }
            .map { ($0.startDate, $0.endDate) }
    }
}
