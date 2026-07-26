import EventKit
import Foundation
import UIKit

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

    /// Whether she has already said yes.
    ///
    /// Checked before *reading* her diary. Asking is a modal alert that freezes
    /// the screen behind it until it's answered — fine when she just tapped
    /// "put it in the diary", wrong when she only opened the calendar to look at
    /// it, where it reads as a screen that won't scroll.
    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Whether asking would show the alert, rather than silently failing
    /// against a decision she already made in Settings.
    static var canAsk: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    /// Enough access to *write* the appointment, which is less than we ask for.
    ///
    /// iOS 17 added "Add Events Only", and someone who picked it can still have
    /// her diary entry — she just can't have C12 scheduling around her day.
    /// Refusing the write because we didn't get everything we wanted would be
    /// our problem, not hers.
    static var canWrite: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly: true
        default: false
        }
    }

    /// She has already said no, or turned it off later. Asking again does
    /// nothing at all — the only way through is Settings, so the UI offers it.
    static var isDenied: Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .denied, .restricted: true
        default: false
        }
    }

    func requestAccess() async throws {
        guard try await store.requestFullAccessToEvents() else {
            throw CalendarError.accessDenied
        }
    }

    /// The permission a diary write actually needs.
    ///
    /// Asks for full access — one prompt, and C12 gets what it needs from the
    /// same tap — but accepts write-only if that is what she has already given.
    private func requestWriteAccess() async throws {
        guard !Self.canWrite else { return }
        try await requestAccess()
    }

    /// Writes the event, or rewrites the one this row wrote last time.
    ///
    /// Keyed on the id of whatever asked for it — the artifact from a Review
    /// card, the timeline event from the calendar screen — the same way
    /// `ReminderService` keys its notification request. Approving can fail
    /// *after* the diary write — a dropped connection on the status PATCH leaves
    /// a "Try again" button that re-runs this method — and without a key that
    /// second tap would put a second consultant's appointment in her real
    /// calendar.
    @discardableResult
    func add(_ payload: CalendarEventPayload, keyedOn key: UUID) async throws -> String {
        try await requestWriteAccess()

        let event = try existingEvent(for: key, matching: payload) ?? newEvent()
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
        Self.remember(event.eventIdentifier, for: key)
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

    /// The event this key wrote before, or one already in her diary that is
    /// plainly the same appointment.
    ///
    /// The second half matters because the same appointment can now be offered
    /// from two places — the Review card and the calendar screen — under two
    /// different ids, and because she may simply have typed it in herself. Any
    /// of those routes ending in a second "Dr Okafor, neurology" on 14 August is
    /// the bug from ISSUES.md #1 arriving through a different door.
    ///
    /// Nil if she has since deleted the event by hand, in which case writing a
    /// fresh one is right.
    private func existingEvent(for key: UUID, matching payload: CalendarEventPayload) -> EKEvent? {
        if let identifier = Self.rememberedIdentifier(for: key),
           let event = store.event(withIdentifier: identifier) {
            return event
        }

        // Needs read access, which "Add Events Only" doesn't grant. Without it
        // we can't look, so we write — a duplicate is better than losing the
        // appointment entirely.
        guard Self.hasAccess else { return nil }

        let window = Self.dayWindow(payload.startsAt)
        let predicate = store.predicateForEvents(
            withStart: window.start, end: window.end, calendars: nil
        )
        return store.events(matching: predicate)
            .first { Self.isSameAppointment($0.title, as: payload.title) }
    }

    /// Two titles for one appointment, judged the way she would.
    ///
    /// Same day already, so an exact match or one title containing the other
    /// ("Dr Okafor" inside "Dr Okafor, neurology") is the same thing. Containment
    /// needs a reasonable length behind it, or a diary entry called "Mum" would
    /// swallow everything on the day. Never matched on time alone: her 14:30
    /// work meeting is not the 14:30 appointment, and editing it in place would
    /// destroy something of hers.
    nonisolated private static func isSameAppointment(_ title: String?, as ours: String) -> Bool {
        let theirs = fold(title ?? "")
        let ours = fold(ours)
        guard !theirs.isEmpty, !ours.isEmpty else { return false }
        if theirs == ours { return true }
        return min(theirs.count, ours.count) >= 6
            && (theirs.contains(ours) || ours.contains(theirs))
    }

    nonisolated private static func fold(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
    ///
    /// Never prompts. A screen that only *reads* her diary asks for nothing —
    /// it says what it would do with access and offers a button (see the
    /// calendar's tablets section), and the answer arrives through
    /// `requestAccess()` on a tap she chose to make.
    func busyBlocks(from start: Date, to end: Date) async throws -> [(start: Date, end: Date)] {
        guard Self.hasAccess else { throw CalendarError.accessDenied }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.availability != .free }
            .map { ($0.startDate, $0.endDate) }
    }

    /// The titles already in her phone's diary on a day.
    ///
    /// So the calendar screen can say which appointments have actually reached
    /// the Calendar app and which are still only CareAid's, rather than assuming
    /// an approved card is proof — she may have deleted it since.
    ///
    /// Never prompts, for the same reason `busyBlocks` doesn't: this runs when a
    /// screen loads, and a permission alert nobody asked for is how the calendar
    /// screen used to freeze.
    func titles(on day: Date) async throws -> [String] {
        guard Self.hasAccess else { throw CalendarError.accessDenied }
        let window = Self.dayWindow(day)
        let predicate = store.predicateForEvents(
            withStart: window.start, end: window.end, calendars: nil
        )
        return store.events(matching: predicate).compactMap(\.title)
    }

    /// True when one of `titles` is plainly this appointment.
    nonisolated static func diaryContains(_ title: String, in titles: [String]) -> Bool {
        titles.contains { isSameAppointment($0, as: title) }
    }

    /// A day, in London, as the pair of instants EventKit wants.
    nonisolated static func dayWindow(_ date: Date) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        return (start, end)
    }

    // MARK: - The Calendar app

    /// Opens the stock Calendar app on the day the appointment sits on.
    ///
    /// The entry is hers once it's written, so the app has to be able to hand
    /// her over to where the rest of her life is. There is no public API for
    /// "show me this event" — `calshow:` takes seconds since the reference date
    /// and lands on the day, which is the part that matters: she sees CareAid's
    /// entry sitting among her own.
    @MainActor
    @discardableResult
    static func openSystemCalendar(on date: Date) async -> Bool {
        guard let url = URL(string: "calshow:\(Int(date.timeIntervalSinceReferenceDate))") else {
            return false
        }
        return await UIApplication.shared.open(url)
    }

    /// The only route left once she's said no — `requestFullAccessToEvents`
    /// returns false without showing anything after that.
    @MainActor
    static func openSettings() async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        await UIApplication.shared.open(url)
    }
}
