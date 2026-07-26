import SwiftUI

/// The mic. The single most important control in the app.
///
/// CLAUDE.md §8 allows Liquid Glass here, and this is a considered departure
/// from that permission: a tinted glass disc on a sage ground is low-contrast
/// by nature, and the one control the whole product depends on should not be
/// the faintest thing on the screen. So it is a solid dome — a lit top face, a
/// shadow beneath it, and a halo that breathes so it reads as *ready* rather
/// than as a picture of a button. Everything else on Home stays still, which is
/// what makes the one moving thing mean something.
struct MicButton: View {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                halo
                dome
            }
        }
        .buttonStyle(TactileButtonStyle(radius: Theme.Size.micDiameter / 2))
        .accessibilityLabel("Record a note")
        .accessibilityHint("Say what happened. You don't have to be tidy.")
    }

    /// A soft ring of accent around the dome. It used to breathe; it does not
    /// any more. Home is the screen she opens at 3am, and a thing that pulses
    /// forever in the middle of it is an alarm, not an invitation — the size
    /// and the shadow already say "press this" without ever moving.
    private var halo: some View {
        Circle()
            .fill(Theme.Palette.accent.opacity(0.12))
            .frame(
                width: Theme.Size.micDiameter + Theme.Size.micHalo * 2,
                height: Theme.Size.micDiameter + Theme.Size.micHalo * 2
            )
    }

    private var dome: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: Theme.Size.micGlyph, weight: .medium))
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(width: Theme.Size.micDiameter, height: Theme.Size.micDiameter)
            .background(
                RadialGradient(
                    colors: [Theme.Palette.accentLit, Theme.Palette.accent],
                    center: .init(x: 0.5, y: 0.32),
                    startRadius: 0,
                    endRadius: Theme.Size.micDiameter * 0.75
                )
            )
            .clipShape(.circle)
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.Palette.highlight, .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: Theme.Size.highlightEdge
                    )
            }
    }
}

#Preview {
    MicButton {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface)
}
