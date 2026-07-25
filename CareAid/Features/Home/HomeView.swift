import SwiftUI

/// Home. The mic dominates; everything else is a glance or a way through.
///
/// Explicitly not a chat UI — no bubbles, no transcript, no AI reply on screen
/// (CLAUDE.md §8).
struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScreenScaffold(fillsHeight: true) {
            VStack(spacing: Theme.Space.xl) {
                Text("How's \(appState.recipientDisplayName)?")
                    .themeFont(Theme.TypeScale.screenTitle)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer(minLength: Theme.Space.l)

                MicButton {
                    // Capture arrives in C9. Text capture lands first, in C6.
                }

                captureAlternatives

                Spacer(minLength: Theme.Space.l)

                todayStrip
                upcoming
            }
            .frame(maxWidth: .infinity)
        }
        .toolbar { destinationIcons }
    }

    // MARK: - Pieces

    /// Side by side normally; stacked once the labels stop fitting, rather than
    /// truncating them.
    private var captureAlternatives: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Space.m) {
                typeButton
                photoButton
            }
            VStack(spacing: Theme.Space.m) {
                typeButton
                photoButton
            }
        }
    }

    private var typeButton: some View {
        SecondaryButton("Type it", systemImage: "keyboard") {
            appState.path.append(.textCapture)
        }
    }

    private var photoButton: some View {
        SecondaryButton("Photo", systemImage: "camera") {}
    }

    /// Today's timeline, three items maximum. Empty until C4 wires up the DB.
    private var todayStrip: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Today")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                Text("Nothing recorded yet.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    /// The next two things coming up.
    private var upcoming: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Coming up")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                Text("Nothing in the diary.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    @ToolbarContentBuilder
    private var destinationIcons: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            toolbarLink(to: .timeline, icon: "clock.arrow.circlepath", label: "Timeline")
            toolbarLink(to: .schedule, icon: "pills", label: "Schedule")
            toolbarLink(to: .appointmentPack, icon: "stethoscope", label: "Appointments")
            #if DEBUG
            toolbarLink(to: .themeGallery, icon: "paintpalette", label: "Theme gallery")
            #endif
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
