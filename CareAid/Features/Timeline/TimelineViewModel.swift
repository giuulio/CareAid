import Foundation
import Observation

@Observable
final class TimelineViewModel {

    enum State {
        case loading
        case loaded
        case failed(String)
    }

    /// A day's worth of entries, newest day first.
    struct Day: Identifiable {
        let id: Date
        let label: String
        let events: [TimelineEvent]
    }

    private(set) var state: State = .loading
    private(set) var brief: Brief?
    private(set) var days: [Day] = []

    func load() async {
        state = .loading
        do {
            let timeline = try TimelineRepository()
            let briefs = try BriefRepository()

            // One round trip each, in parallel — the brief does not depend on
            // the events.
            async let eventsTask = timeline.recent()
            async let briefTask = briefs.current()
            let (events, brief) = try await (eventsTask, briefTask)

            self.brief = brief
            self.days = Self.group(events)
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Reverse chronological, grouped by day — CLAUDE.md §8.
    private static func group(_ events: [TimelineEvent]) -> [Day] {
        let byDay = Dictionary(grouping: events) {
            DisplayDate.startOfDay(for: $0.occurredAt)
        }
        return byDay
            .map { start, events in
                Day(
                    id: start,
                    label: DisplayDate.dayLabel(for: start),
                    events: events.sorted { $0.occurredAt > $1.occurredAt }
                )
            }
            .sorted { $0.id > $1.id }
    }
}
