import SwiftUI

/// The living brief, pinned at the top of the Timeline.
///
/// The one-liner is the largest text in the app on purpose — if Sarah reads
/// one thing, it is this.
struct BriefCard: View {
    let brief: Brief

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Text(brief.content.oneLiner)
                    .themeFont(Theme.TypeScale.briefOneLiner)
                    .foregroundStyle(Theme.Palette.ink)

                if !brief.content.currentConcerns.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        ForEach(Array(brief.content.currentConcerns.enumerated()), id: \.offset) { _, concern in
                            concernRow(concern)
                        }
                    }
                }
            }
        }
    }

    private func concernRow(_ concern: Concern) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            Image(systemName: symbol(for: concern.trend))
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.accent)
            Text(concern.text)
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    /// Direction of travel only. Never a severity or a judgement — rule 1.
    private func symbol(for trend: Trend?) -> String {
        switch trend {
        case .worsening: "arrow.up.right"
        case .improving: "arrow.down.right"
        case .stable, nil: "arrow.right"
        }
    }
}
