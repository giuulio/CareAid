import SwiftUI

/// A quieter action that is still a visible, full-size button.
///
/// CLAUDE.md §8 forbids gesture-only actions, so "Not this", "Type instead" and
/// friends all get real hit area — never a bare text link. Quieter than
/// `PrimaryButton` by fill and elevation only; the type size and the hit area
/// match it, because "secondary" must never mean "harder to hit".
struct SecondaryButton: View {
    private let title: String
    private let systemImage: String?
    private let height: CGFloat
    private let action: () -> Void

    /// `height` is here for one case: a yes/no pair, where the two buttons are
    /// one decision and must be the same size. Everywhere else it stays at the
    /// secondary height and nobody passes it.
    init(
        _ title: String,
        systemImage: String? = nil,
        height: CGFloat = Theme.Size.secondaryButtonHeight,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.height = height
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .themeFont(Theme.TypeScale.icon)
                }
                Text(title)
            }
            .themeFont(Theme.TypeScale.bodyStrong)
            .foregroundStyle(Theme.Palette.ink)
            .frame(maxWidth: .infinity)
            // minHeight, not height: at accessibility type sizes a two-line
            // label inside a fixed 60pt box gets clipped, and losing half of
            // "Not quite — say it again" is worse than an uneven pair.
            .frame(minHeight: height)
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.s)
            .background(Theme.Palette.surfaceRaised)
            .clipShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
            // A drawn border, not a lit edge. This button sits on the sage
            // background *and* nested inside white cards ("See what I said"),
            // and a white-on-white highlight is invisible in the second case —
            // the control disappears into the card it is sitting on. The
            // hairline reads against both.
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(TactileButtonStyle(radius: Theme.Radius.medium, raised: false))
    }
}

#Preview {
    HStack(spacing: Theme.Space.m) {
        SecondaryButton("Type it", systemImage: "keyboard") {}
        SecondaryButton("Photo", systemImage: "camera") {}
    }
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
