#if DEBUG
import SwiftUI

/// Every design token on one page. Debug builds only.
///
/// This exists so the C13 design pass is a visual edit: change a value in
/// `Theme.swift`, look here, decide. Flip the simulator between light and dark
/// to check both halves of each colour token at once.
struct ThemeGallery: View {
    var body: some View {
        ScreenScaffold(title: "Theme") {
            section("Palette") {
                swatch("surface", Theme.Palette.surface)
                swatch("surfaceRaised", Theme.Palette.surfaceRaised)
                swatch("ink", Theme.Palette.ink)
                swatch("inkSecondary", Theme.Palette.inkSecondary)
                swatch("accent", Theme.Palette.accent)
                swatch("onAccent", Theme.Palette.onAccent)
                swatch("accentSoft", Theme.Palette.accentSoft)
                swatch("hairline", Theme.Palette.hairline)
            }

            section("Type scale") {
                specimen("briefOneLiner", Theme.TypeScale.briefOneLiner)
                specimen("screenTitle", Theme.TypeScale.screenTitle)
                specimen("cardHeadline", Theme.TypeScale.cardHeadline)
                specimen("button", Theme.TypeScale.button)
                specimen("body", Theme.TypeScale.body)
                specimen("bodyStrong", Theme.TypeScale.bodyStrong)
                specimen("meta", Theme.TypeScale.meta)
                specimen("icon", Theme.TypeScale.icon)
            }

            section("Spacing") {
                spaceBar("xs", Theme.Space.xs)
                spaceBar("s", Theme.Space.s)
                spaceBar("m", Theme.Space.m)
                spaceBar("l", Theme.Space.l)
                spaceBar("xl", Theme.Space.xl)
                spaceBar("xxl", Theme.Space.xxl)
                spaceBar("xxxl", Theme.Space.xxxl)
            }

            section("Components") {
                PrimaryButton("Primary action", systemImage: "checkmark") {}
                SecondaryButton("Secondary action", systemImage: "xmark") {}
                MicButton {}
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Building blocks

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title)
                .themeFont(Theme.TypeScale.cardHeadline)
                .foregroundStyle(Theme.Palette.ink)
            content()
        }
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        HStack(spacing: Theme.Space.m) {
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(color)
                .frame(width: Theme.Size.minTouchTarget, height: Theme.Size.minTouchTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
                }
            Text(name)
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.ink)
        }
    }

    private func specimen(_ name: String, _ token: Theme.TypeToken) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("How's Mum?")
                .themeFont(token)
                .foregroundStyle(Theme.Palette.ink)
            Text("\(name) · \(Int(token.size))pt")
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    private func spaceBar(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: Theme.Space.m) {
            Rectangle()
                .fill(Theme.Palette.accent)
                .frame(width: value, height: Theme.Space.xl)
            Text("\(name) · \(Int(value))")
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }
}

#Preview {
    NavigationStack { ThemeGallery() }
}
#endif
