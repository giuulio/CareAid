import SwiftUI

/// What a card shows while it is doing the thing.
///
/// Never a bare spinner — CLAUDE.md §8. She has just tapped something that
/// writes to her phone, and silence is the moment she taps again.
struct WorkingLabel: View {
    var body: some View {
        ThinkingIndicator(label: "Just a moment…", symbol: "hourglass")
            .frame(minHeight: Theme.Size.secondaryButtonHeight)
    }
}

/// A decision that has been made. Stays on screen so she can see what she just
/// did, rather than watching the card vanish from under her thumb.
///
/// Static. The confirmation is that the button she pressed has been *replaced*
/// by a tick and a word — a change she cannot miss without anything needing to
/// animate to sell it. The haptic already fired when she pressed.
struct SettledLabel: View {
    let label: String
    let symbol: String

    init(_ label: String, symbol: String) {
        self.label = label
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: symbol)
                .themeFont(Theme.TypeScale.icon)
            Text(label)
                .themeFont(Theme.TypeScale.bodyStrong)
        }
        .foregroundStyle(Theme.Palette.accent)
        .frame(minHeight: Theme.Size.secondaryButtonHeight)
    }
}
