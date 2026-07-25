import SwiftUI

/// A solid, opaque content container.
///
/// Deliberately never glass. CLAUDE.md §8: Liquid Glass is for chrome only —
/// body text on a translucent surface is low-contrast by nature, and this app's
/// reader may be tired and presbyopic.
struct Card<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            // Take the full height the text needs. Without this a card in a
            // height-constrained stack silently truncates its body copy at
            // large type sizes, which is the one thing we cannot ship.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.l)
            .background(Theme.Palette.surfaceRaised)
            .clipShape(.rect(cornerRadius: Theme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
            }
    }
}

#Preview {
    VStack(spacing: Theme.Space.l) {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Evening dose missed")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                Text("Found still in the tray.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
