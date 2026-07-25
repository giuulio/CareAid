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

    @discardableResult
    func add(_ payload: CalendarEventPayload) async throws -> String {
        try await requestAccess()

        guard let calendar = store.defaultCalendarForNewEvents else {
            throw CalendarError.noDefaultCalendar
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = payload.title
        event.startDate = payload.startsAt
        // An appointment with no stated end still needs one; an hour is a
        // reasonable guess for a consultation and she can edit it.
        event.endDate = payload.endsAt ?? payload.startsAt.addingTimeInterval(3600)
        event.location = payload.location
        event.notes = payload.notes

        for minutes in payload.remindersMin {
            event.addAlarm(EKAlarm(relativeOffset: -Double(minutes) * 60))
        }

        try store.save(event, span: .thisEvent)
        return event.eventIdentifier
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
