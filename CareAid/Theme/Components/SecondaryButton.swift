import SwiftUI

/// A quieter action that is still a visible, full-size button.
///
/// CLAUDE.md §8 forbids gesture-only actions, so "Not this", "Type instead" and
/// friends all get real hit area — 56pt minimum, never a bare text link.
struct SecondaryButton: View {
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
            .frame(height: Theme.Size.secondaryButtonHeight)
            .background(Theme.Palette.surfaceRaised)
            .clipShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: Theme.Space.m) {
        SecondaryButton("Type instead", systemImage: "keyboard") {}
        SecondaryButton("Photo", systemImage: "camera") {}
    }
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
