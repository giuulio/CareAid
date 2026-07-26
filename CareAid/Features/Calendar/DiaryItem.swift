import Foundation

/// One appointment on a day, whichever of CareAid's records it came from.
///
/// A day's appointments arrive from two places that don't know about each other:
/// `timeline_event` rows of kind `appointment`, which write themselves because
/// recording needs no permission (§2 rule 4), and approved `calendar_event`
/// artifacts, which are the ones that reached her phone. They are usually the
/// *same* appointment seen twice — the demo's Dr Okafor is seeded as a timeline
/// event and proposed as a card — so they are merged into one row here rather
/// than listed twice on the day she'd be reading at 3am.
nonisolated struct DiaryItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String?
    let startsAt: Date
    let location: String?
    /// Minutes before, for the write. `[1440, 60]` throughout — a day before,
    /// then an hour before.
    let remindersMin: [Int]

    /// A matching entry is in the phone's Calendar app *now*. Read from
    /// EventKit each time rather than inferred from an approved artifact: she
    /// may have deleted it since, and claiming it's in her diary when it isn't
    /// is the one thing worse than not offering to put it there.
    var inPhoneCalendar = false

    /// What gets written if it isn't there yet.
    var payload: CalendarEventPayload {
        CalendarEventPayload(
            title: title,
            startsAt: startsAt,
            endsAt: nil,
            location: location,
            notes: detail,
            remindersMin: remindersMin
        )
    }

    // MARK: - From each record

    init(_ event: TimelineEvent) {
        id = event.id
        title = event.headline
        detail = event.detail
        startsAt = event.occurredAt
        location = nil
        remindersMin = [1440, 60]
    }

    init?(_ artifact: Artifact) {
        guard case .calendarEvent(let payload) = artifact.payload else { return nil }
        id = artifact.id
        title = payload.title
        detail = payload.notes
        startsAt = payload.startsAt
        location = payload.location
        remindersMin = payload.remindersMin
    }

    // MARK: - Merging

    /// The day's appointments, each appearing once.
    ///
    /// Timeline events lead because they are what CareAid recorded and what the
    /// rest of the screen is built from; an approved diary entry that matches
    /// one adds nothing but its location, so it drops out. One that matches
    /// nothing is an appointment we only know about because she approved it,
    /// and it belongs on the day just as much.
    static func merged(appointments: [TimelineEvent], diary: [Artifact]) -> [DiaryItem] {
        var items = appointments.map(DiaryItem.init)

        for entry in diary.compactMap(DiaryItem.init) {
            let duplicate = items.contains {
                CalendarService.diaryContains(entry.title, in: [$0.title])
            }
            if !duplicate { items.append(entry) }
        }

        return items.sorted { $0.startsAt < $1.startsAt }
    }
}
