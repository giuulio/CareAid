import SwiftUI

/// The one large, obvious action on a screen or card. 72pt tall — CLAUDE.md §8.
///
/// Label copy is the caller's job and should be human: "Tell Tom", not
/// "Send family update".
///
/// Physically a key: a lit top face, a shadow underneath, travel and a haptic
/// tick when it goes down. That is the useful half of skeuomorphism — the
/// affordance, not the leather stitching.
struct PrimaryButton: View {
    private let title: String
    private let systemImage: String?
    private let action: () -> Void

    init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.m) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .themeFont(Theme.TypeScale.icon)
                }
                Text(title)
            }
            .themeFont(Theme.TypeScale.button)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Size.primaryButtonHeight)
            .padding(.horizontal, Theme.Space.l)
            .background(
                LinearGradient(
                    colors: [Theme.Palette.accentLit, Theme.Palette.accent],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
            .litEdge(radius: Theme.Radius.medium)
            // The whole 72pt is the target, not just where the glyphs land.
            .contentShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(TactileButtonStyle(radius: Theme.Radius.medium))
    }
}

#Preview {
    VStack(spacing: Theme.Space.l) {
        PrimaryButton("Put it in the diary", systemImage: "calendar") {}
        PrimaryButton("Tell Tom") {}
    }
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
