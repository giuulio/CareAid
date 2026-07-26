import SwiftUI

/// One of Home's two glance cards: a heading, a few lines, and a way through
/// to the screen that holds the rest.
///
/// The whole card is the tap target, so it clears the 56pt floor by a mile and
/// there is no small chevron to aim at. CLAUDE.md §8 wants every action visible
/// — the chevron is a hint, not the mechanism.
struct HomeGlanceCard: View {
    let title: String
    /// Shown instead of the rows when there is genuinely nothing.
    let emptyText: String
    let events: [TimelineEvent]
    /// How each row labels itself: a clock time today, a day name ahead.
    let label: (TimelineEvent) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .themeFont(Theme.TypeScale.cardHeadline)
                            .foregroundStyle(Theme.Palette.ink)
                        Spacer(minLength: Theme.Space.s)
                        Image(systemName: "chevron.right")
                            .themeFont(Theme.TypeScale.meta)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }

                    if events.isEmpty {
                        Text(emptyText)
                            .themeFont(Theme.TypeScale.body)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    } else {
                        ForEach(events) { event in
                            row(event)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private func row(_ event: TimelineEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            Image(systemName: event.kind.symbol)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.accent)
                // Keeps the headlines left-aligned with each other rather than
                // ragged behind glyphs of different widths.
                .frame(width: Theme.Space.xl, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(event.headline)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(label(event))
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}
