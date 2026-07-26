import SwiftUI

/// The CareAid mark: two crossed plasters, one behind the other.
///
/// Drawn rather than bundled. `Assets.xcassets` holds the same mark as a
/// 1024pt PNG, but an iOS app icon must be flattened onto white with no alpha —
/// dropping that file onto warm paper puts a white tile around it, and it would
/// need a second copy for dark mode. Two capsules cost less than the asset and
/// inherit the palette, so the mark is correct in both appearances for free.
///
/// The back arm is the accent at 45%, which is what the flat artwork's lighter
/// blue resolves to over white — the two-tone look is one colour, twice.
struct BrandMark: View {
    /// Height and width of the mark's bounding box.
    let size: CGFloat

    var body: some View {
        ZStack {
            arm.rotationEffect(.degrees(45))
                .foregroundStyle(Theme.Palette.accent.opacity(0.45))
            arm.rotationEffect(.degrees(-45))
                .foregroundStyle(Theme.Palette.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Sized so the rotated pair still fits the box: a bar at 45° needs its
    /// length divided by √2 to stay inside the square it is drawn in.
    private var arm: some View {
        Capsule(style: .continuous)
            .frame(width: size * 0.30, height: size * 0.92)
    }
}

#Preview {
    VStack(spacing: Theme.Space.xl) {
        BrandMark(size: 120)
        BrandMark(size: 56)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
