import SwiftUI

/// One recorded entry.
struct TimelineEventRow: View {
    let event: TimelineEvent

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                    Image(systemName: Self.symbol(for: event.kind))
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.accent)
                    Text(DisplayDate.time(event.occurredAt))
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }

                Text(event.headline)
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)

                if let detail = event.detail {
                    Text(detail)
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
    }

    /// Categorical only — which *kind* of thing happened, never how bad it is.
    static func symbol(for kind: TimelineEventKind) -> String {
        switch kind {
        case .symptom: "waveform.path"
        case .medication: "pills"
        case .incident: "exclamationmark.triangle"
        case .appointment: "stethoscope"
        case .mood: "face.smiling"
        case .careTask: "hands.and.sparkles"
        case .admin: "tray.full"
        }
    }
}
