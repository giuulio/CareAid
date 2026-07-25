import Foundation
import Observation

/// What Home shows underneath the mic: what has happened today, and the next
/// couple of things coming.
///
/// Both are glances, not screens — three items and two items, per CLAUDE.md §8.
/// The full lists are one tap away and already built.
@Observable
final class HomeViewModel {

    enum State {
        case loading
        case loaded
        /// Home must never be a dead end. On failure the mic still works, so
        /// this renders as a quiet line rather than an error screen.
        case failed(String)
    }

    /// §8 caps the strip at three.
    static let todayLimit = 3

    /// "the next two upcoming things".
    static let upcomingLimit = 2

    private(set) var state: State = .loading
    private(set) var today: [TimelineEvent] = []
    private(set) var upcoming: [TimelineEvent] = []

    func load() async {
        // Deliberately not resetting to `.loading` on a reload: this method runs
        // again every time the Review sheet closes, and blanking the cards she
        // is looking at to show a spinner is worse than a stale half-second.
        do {
            let timeline = try TimelineRepository()

            async let recentTask = timeline.recent()
            async let upcomingTask = timeline.upcoming(limit: Self.upcomingLimit)
            let (recent, ahead) = try await (recentTask, upcomingTask)

            let startOfToday = DisplayDate.startOfDay(for: .now)
            today = recent
                .filter { $0.occurredAt >= startOfToday }
                .prefix(Self.todayLimit)
                .map { $0 }
            upcoming = ahead
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
