import SwiftUI

/// "That's the third missed evening dose this month."
///
/// The whole reason 90 days of history gets sent with every capture. Sits above
/// the cards because it reframes everything below it, and it is the one thing
/// on the sheet that is neither a record nor a decision — so it gets the accent
/// fill and a filled glyph, rather than another white card she has to read to
/// discover it is different. Colour and weight do that work; nothing here
/// animates.
struct PatternBanner: View {
    let patterns: [Pattern]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ForEach(Array(patterns.enumerated()), id: \.offset) { _, pattern in
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .themeFont(Theme.TypeScale.icon)
                        .foregroundStyle(Theme.Palette.onAccent)
                        .frame(width: Theme.Space.xxl, height: Theme.Space.xxl)
                        .background(Theme.Palette.accent, in: .circle)

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
        .litEdge(radius: Theme.Radius.large)
        .depth(contact: Theme.Depth.restingContact, ambient: Theme.Depth.restingAmbient)
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
            HStack(alignment: .top, spacing: Theme.Space.m) {
                Image(systemName: isEscalation ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                    .themeFont(Theme.TypeScale.icon)
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: Theme.Space.xxl, height: Theme.Space.xxl)
                    .background(Theme.Palette.accentSoft, in: .circle)

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

/// An event that has already been written. Recessed and unactionable —
/// recording needs no permission, only acting does (CLAUDE.md §2, rule 4).
///
/// It sits *into* the page while the proposals sit on top of it, so "already
/// done" and "needs you" are told apart by depth before a word is read.
struct RecordedEntry: View {
    let event: TimelineEvent

    var body: some View {
        Card(prominence: .quiet) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: event.kind.symbol)
                        .themeFont(Theme.TypeScale.meta)
                    Text("Saved · \(DisplayDate.time(event.occurredAt))")
                        .themeFont(Theme.TypeScale.meta)
                }
                .foregroundStyle(Theme.Palette.inkSecondary)

                Text(event.headline)
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.ink)

                if let detail = event.detail {
                    Text(detail)
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }
    }
}
