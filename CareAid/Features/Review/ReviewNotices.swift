import SwiftUI

/// "That's the third missed evening dose this month."
///
/// The whole reason 90 days of history gets sent with every capture. Sits above
/// the cards because it reframes everything below it.
struct PatternBanner: View {
    let patterns: [Pattern]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            ForEach(Array(patterns.enumerated()), id: \.offset) { _, pattern in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .themeFont(Theme.TypeScale.icon)
                        .foregroundStyle(Theme.Palette.accent)
                    Text(pattern.observation)
                        .themeFont(Theme.TypeScale.bodyStrong)
                        .foregroundStyle(Theme.Palette.ink)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.l)
        .background(Theme.Palette.accentSoft)
        .clipShape(.rect(cornerRadius: Theme.Radius.large, style: .continuous))
    }
}

/// Things the model would not guess at (§7 rule 2) and anything that might need
/// urgent attention (rule 6). Never an instruction — always a question.
struct FlagNotice: View {
    let flag: Flag
    /// Used only to check whether `flag.text` really is her words before we
    /// quote it back at her.
    let transcript: String

    var body: some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                Image(systemName: isEscalation ? "exclamationmark.triangle" : "questionmark.circle")
                    .themeFont(Theme.TypeScale.icon)
                    .foregroundStyle(Theme.Palette.accent)
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(flag.ask)
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.ink)
                    if let text = flag.text, !text.isEmpty {
                        // Only attribute it to her if she actually said it. The
                        // model sometimes puts its own reasoning in this field,
                        // and quoting that back as her words is a small lie.
                        Text(isQuote(text) ? "You said: “\(text)”" : text)
                            .themeFont(Theme.TypeScale.meta)
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                }
            }
        }
    }

    private var isEscalation: Bool {
        flag.type == .possibleEscalation
    }

    private func isQuote(_ text: String) -> Bool {
        transcript.localizedCaseInsensitiveContains(text.trimmingCharacters(in: .punctuationCharacters))
    }
}

/// An event that has already been written. Greyed and unactionable — recording
/// needs no permission, only acting does (CLAUDE.md §2, rule 4).
struct RecordedEntry: View {
    let event: TimelineEvent

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: TimelineEventRow.symbol(for: event.kind))
                        .themeFont(Theme.TypeScale.meta)
                    Text("Saved · \(DisplayDate.time(event.occurredAt))")
                        .themeFont(Theme.TypeScale.meta)
                }
                .foregroundStyle(Theme.Palette.inkSecondary)

                Text(event.headline)
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.inkSecondary)

                if let detail = event.detail {
                    Text(detail)
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
    }
}
