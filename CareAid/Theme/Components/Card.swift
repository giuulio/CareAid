import SwiftUI

/// A solid, opaque content container with a real thickness to it.
///
/// Deliberately never glass. CLAUDE.md §8: Liquid Glass is for chrome only —
/// body text on a translucent surface is low-contrast by nature, and this app's
/// reader may be tired and presbyopic.
///
/// The depth is additive, never load-bearing: white on sage already clears 7:1
/// with every shadow switched off. The shadow says *this is one thing, and it
/// is nearer than the page* — a job the old hairline border did less well,
/// because a 1pt line is the first thing to disappear in bad light.
struct Card<Content: View>: View {
    /// Cards that are only a record — the auto-committed entries on Review —
    /// sit flatter than cards asking for a decision. Hierarchy you can see
    /// without reading a word.
    var prominence: Prominence = .standard

    private let content: Content

    enum Prominence {
        case standard
        case quiet
    }

    init(prominence: Prominence = .standard, @ViewBuilder content: () -> Content) {
        self.prominence = prominence
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
            .background(fill)
            .clipShape(.rect(cornerRadius: Theme.Radius.large, style: .continuous))
            .litEdge(radius: Theme.Radius.large)
            .depth(contact: contact, ambient: ambient)
    }

    private var fill: Color {
        switch prominence {
        case .standard: Theme.Palette.surfaceRaised
        case .quiet: Theme.Palette.surfaceSunken
        }
    }

    private var contact: Theme.Depth.ShadowToken {
        switch prominence {
        case .standard: Theme.Depth.restingContact
        case .quiet: Theme.Depth.ShadowToken(opacity: 0.03, radius: 1, y: 1)
        }
    }

    private var ambient: Theme.Depth.ShadowToken {
        switch prominence {
        case .standard: Theme.Depth.restingAmbient
        case .quiet: Theme.Depth.ShadowToken(opacity: 0.04, radius: 8, y: 3)
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
        Card(prominence: .quiet) {
            Text("Saved · 8:00 pm")
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
