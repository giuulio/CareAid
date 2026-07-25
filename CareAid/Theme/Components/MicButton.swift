import SwiftUI

/// The mic. The single most important control in the app.
///
/// One of the few places Liquid Glass is allowed (CLAUDE.md §8) — it is chrome,
/// not content, and carries no body text. Tinted with the accent so it stays
/// legible against warm paper rather than dissolving into it.
struct MicButton: View {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: Theme.Size.micGlyph, weight: .medium))
                .foregroundStyle(Theme.Palette.onAccent)
                .frame(width: Theme.Size.micDiameter, height: Theme.Size.micDiameter)
                .glassEffect(
                    .regular.tint(Theme.Palette.accent).interactive(),
                    in: .circle
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record a note")
    }
}

#Preview {
    MicButton {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.surface)
}
