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
                header

                Spacer(minLength: Theme.Space.xl)

                // The only sentence on the screen, and the lightest thing on
                // it. `CareAid` above is the one bold weight up here; the
                // greeting is a question, and reads better asked than
                // announced.
                Text("How are we helping \(appState.recipientDisplayName) today?")
                    .themeFont(Theme.TypeScale.hero)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: Theme.Space.l)

                MicButton {
                    appState.path.append(.voiceCapture)
                }

                // Everything above is centred on the mic; typing is the way out
                // for the night she cannot speak, so it waits at the bottom
                // where her thumb already is rather than competing on the way
                // down to it.
                Spacer(minLength: Theme.Space.xxl)

                typeButton
            }
            .frame(maxWidth: .infinity)
        }
        // Home draws its own header: the 48pt destination icons do not fit a
        // 44pt system navigation bar, they get clipped.
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Pieces

    /// The calendar holds everything time-shaped, the list holds everything she
    /// takes, and the name sits between them. Equal-width buttons either side
    /// so the wordmark is optically centred rather than centred-ish.
    private var header: some View {
        HStack(spacing: Theme.Space.s) {
            headerLink(to: .calendar, icon: "calendar", label: "Calendar")
            Spacer(minLength: Theme.Space.s)
            Text("CareAid")
                .themeFont(Theme.TypeScale.brandTitle)
                .foregroundStyle(Theme.Palette.accent)
            Spacer(minLength: Theme.Space.s)
            headerLink(to: .medications, icon: "pills", label: "Her medication")
        }
    }

    private var typeButton: some View {
        Button {
            appState.path.append(.textCapture)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Palette.surfaceRaised.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: Theme.Size.keyboardButtonHeight + Theme.Space.l)

                Image(systemName: "keyboard")
                    .font(.system(size: Theme.Size.keyboardGlyph, weight: .medium))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Size.keyboardButtonHeight)
                    .background(Theme.Palette.surfaceRaised)
                    .clipShape(.rect(cornerRadius: Theme.Radius.large, style: .continuous))
                    .litEdge(radius: Theme.Radius.large)
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                            .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
                    }
            }
        }
        .buttonStyle(TactileButtonStyle(radius: Theme.Radius.large))
        .accessibilityLabel("Type a note")
        .accessibilityHint("Write what happened instead of recording it.")
    }

    // Photo capture is deferred, and its button went with it — a visible
    // control that does nothing is worse than one that isn't there, least of
    // all on stage. When it comes back the scope is: photograph a medicine box,
    // a receipt or a letter from the consultant, upload to the `captures`
    // Storage bucket, write `capture.media_url`, and let `extract` read the
    // image alongside the text. `NSCameraUsageDescription` and the `photo`
    // value of `capture.source` are already in place for it.

    private func headerLink(to route: Route, icon: String, label: String) -> some View {
        Button {
            appState.path.append(route)
        } label: {
            Image(systemName: icon)
                .themeFont(Theme.TypeScale.navIcon)
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: Theme.Size.headerIcon, height: Theme.Size.headerIcon)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    RootView()
}
