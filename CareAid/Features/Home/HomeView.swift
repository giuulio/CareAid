import SwiftUI

/// Home. The mic dominates; everything else is a way through.
///
/// Explicitly not a chat UI — no bubbles, no transcript, no AI reply on screen
/// (CLAUDE.md §8).
///
/// One question and one control. The glance cards that used to sit under the
/// mic are gone: they made Home a thing to read before it was a thing to speak
/// into, and everything they showed is one tap away behind the calendar.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScreenScaffold(fillsHeight: true) {
            VStack(spacing: Theme.Space.xl) {
                Spacer(minLength: Theme.Space.xxl)

                // The only sentence on the screen, so it gets to be the largest
                // thing in the app — and the lightest. `CareAid` in the bar is
                // the only bold thing up here; the greeting is a question, not
                // a banner, and reads better spoken than shouted.
                Text("How's \(appState.recipientDisplayName)?")
                    .themeFont(Theme.TypeScale.hero)
                    .foregroundStyle(Theme.Palette.ink)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: Theme.Space.l)

                MicButton {
                    appState.path.append(.voiceCapture)
                }

                Spacer(minLength: Theme.Space.l)

                typeButton

                Spacer(minLength: Theme.Space.xxl)
            }
            .frame(maxWidth: .infinity)
        }
        .toolbar { chrome }
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

    /// The bar: the calendar holds everything time-shaped, the list holds
    /// everything she takes, and the name sits between them.
    @ToolbarContentBuilder
    private var chrome: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            toolbarLink(to: .calendar, icon: "calendar", label: "Calendar")
        }
        ToolbarItem(placement: .principal) {
            Text("CareAid")
                .themeFont(Theme.TypeScale.brandTitle)
                .foregroundStyle(Theme.Palette.ink)
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
