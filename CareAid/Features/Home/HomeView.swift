import SwiftUI

/// Home. The mic dominates; everything else is a glance or a way through.
///
/// Explicitly not a chat UI — no bubbles, no transcript, no AI reply on screen
/// (CLAUDE.md §8).
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var model = HomeViewModel()

    var body: some View {
        ScreenScaffold(fillsHeight: true) {
            VStack(spacing: Theme.Space.xl) {
                Text("How's \(appState.recipientDisplayName)?")
                    .themeFont(Theme.TypeScale.screenTitle)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer(minLength: Theme.Space.l)

                MicButton {
                    appState.path.append(.voiceCapture)
                }

                typeButton

                Spacer(minLength: Theme.Space.l)

                todayStrip
                upcoming
            }
            .frame(maxWidth: .infinity)
        }
        .toolbar { destinationIcons }
        .task { await model.load() }
        // Reload whenever she comes back to Home. What she just recorded should
        // already be sitting under the mic — that moment is the whole promise.
        .onChange(of: appState.path) { _, path in
            guard path.isEmpty else { return }
            Task { await model.load() }
        }
    }

    // MARK: - Pieces

    private var typeButton: some View {
        SecondaryButton("Type it", systemImage: "keyboard") {
            appState.path.append(.textCapture)
        }
    }

    // Photo capture is deferred, and its button went with it — a visible
    // control that does nothing is worse than one that isn't there, least of
    // all on stage. When it comes back the scope is: photograph a medicine box,
    // a receipt or a letter from the consultant, upload to the `captures`
    // Storage bucket, write `capture.media_url`, and let `extract` read the
    // image alongside the text. `NSCameraUsageDescription` and the `photo`
    // value of `capture.source` are already in place for it.

    /// Today's timeline, three items maximum, through to the calendar.
    private var todayStrip: some View {
        HomeGlanceCard(
            title: "Today",
            emptyText: emptyText(otherwise: "Nothing recorded yet."),
            events: model.today,
            label: { DisplayDate.time($0.occurredAt) }
        ) {
            appState.path.append(.calendar)
        }
    }

    /// The next two things coming up, through to the same place.
    private var upcoming: some View {
        HomeGlanceCard(
            title: "Coming up",
            emptyText: emptyText(otherwise: "Nothing in the diary."),
            events: model.upcoming,
            label: { "\(DisplayDate.dayLabel(for: $0.occurredAt)), \(DisplayDate.time($0.occurredAt))" }
        ) {
            appState.path.append(.calendar)
        }
    }

    /// Home is never a dead end. If the backend is unreachable the mic still
    /// works, so say so in one line instead of throwing up an error screen.
    private func emptyText(otherwise empty: String) -> String {
        switch model.state {
        case .loading: "One moment…"
        case .loaded: empty
        case .failed: "Can't reach her records right now. You can still record."
        }
    }

    /// Two icons, one on each side of the mic's sightline: the calendar holds
    /// everything time-shaped, the list holds everything she takes.
    @ToolbarContentBuilder
    private var destinationIcons: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            toolbarLink(to: .calendar, icon: "calendar", label: "Calendar")
        }
        ToolbarItem(placement: .topBarTrailing) {
            toolbarLink(to: .medications, icon: "pills", label: "Her medication")
        }
    }

    private func toolbarLink(to route: Route, icon: String, label: String) -> some View {
        Button {
            appState.path.append(route)
        } label: {
            Image(systemName: icon)
                .themeFont(Theme.TypeScale.icon)
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    RootView()
}
