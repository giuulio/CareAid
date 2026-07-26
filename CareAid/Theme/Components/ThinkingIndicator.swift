import SwiftUI

/// What the app shows while it is working. Never a bare spinner (CLAUDE.md §8).
///
/// A system `ProgressView` says only "something is happening". This says *what*
/// is happening, in her words, and one ring keeps turning so a 13-second round
/// trip never looks like a freeze — the moment where a tired user taps again,
/// or backs out and loses the thought.
///
/// **Exactly one thing moves, and it is never the text.** An earlier version
/// had the ring sweeping, the symbol pulsing and three dots rising at once;
/// that is motion as decoration, and on a screen built for someone tired at 3am
/// it reads as noise. The label sits still and stays readable, which is what it
/// is for.
struct ThinkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    /// The verb, as a glyph. Static — it names the stage, it does not perform
    /// it. Defaults to the waveform, because the commonest wait in the app is
    /// us reading back what she just said.
    var symbol: String = "waveform"

    @State private var sweep = false

    var body: some View {
        HStack(spacing: Theme.Space.l) {
            glyph

            Text(label)
                .themeFont(Theme.TypeScale.bodyStrong)
                .foregroundStyle(Theme.Palette.ink)

            Spacer(minLength: 0)
        }
        .frame(minHeight: Theme.Size.minTouchTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                sweep = true
            }
        }
    }

    private var glyph: some View {
        ZStack {
            Circle()
                .fill(Theme.Palette.accentSoft)

            // The one moving part: a quarter-arc turning at a walking pace.
            // Reads as progress without ever claiming a percentage we don't
            // know, and stops dead under Reduce Motion.
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(Theme.Palette.accent, style: .init(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(sweep ? 360 : 0))

            Image(systemName: symbol)
                .themeFont(Theme.TypeScale.icon)
                .foregroundStyle(Theme.Palette.accent)
        }
        .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Space.xl) {
        ThinkingIndicator(label: "Writing it down…")
        ThinkingIndicator(label: "Reading it back…", symbol: "text.magnifyingglass")
        ThinkingIndicator(label: "Just a moment…", symbol: "hourglass")
    }
    .padding(Theme.Space.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Theme.Palette.surface)
}
