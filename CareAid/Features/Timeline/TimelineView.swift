import SwiftUI

/// Everything recorded about Mum, newest first, grouped by day.
struct TimelineView: View {
    @State private var model = TimelineViewModel()

    var body: some View {
        ScreenScaffold(title: "Timeline") {
            switch model.state {
            case .loading:
                loading
            case .failed(let message):
                failed(message)
            case .loaded:
                loaded
            }
        }
        .task { await model.load() }
    }

    // MARK: - States

    private var loading: some View {
        Card {
            Text("Fetching Mum's history…")
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    private func failed(_ message: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("Couldn't load the timeline")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                Text(message)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                PrimaryButton("Try again", systemImage: "arrow.clockwise") {
                    Task { await model.load() }
                }
            }
        }
    }

    @ViewBuilder
    private var loaded: some View {
        if let brief = model.brief {
            BriefCard(brief: brief)
        }

        if model.days.isEmpty {
            Card {
                Text("Nothing recorded yet. Tap the mic on the home screen and say what happened.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        } else {
            ForEach(model.days) { day in
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text(day.label)
                        .themeFont(Theme.TypeScale.cardHeadline)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    ForEach(day.events) { event in
                        TimelineEventRow(event: event)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { TimelineView() }
}
