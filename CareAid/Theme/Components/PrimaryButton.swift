import SwiftUI

/// The one large, obvious action on a screen or card. 72pt tall — CLAUDE.md §8.
///
/// Label copy is the caller's job and should be human: "Tell Tom", not
/// "Send family update".
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
            .frame(height: Theme.Size.primaryButtonHeight)
            .background(Theme.Palette.accent)
            .clipShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
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
