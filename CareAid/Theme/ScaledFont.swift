import SwiftUI

extension View {
    /// Applies a type token, scaled for Dynamic Type.
    ///
    /// Use this everywhere instead of `.font(...)`. Asked for by point size
    /// alone, both the bundled faces and the system font are *fixed* and ignore
    /// the reader's text-size setting — the one setting this audience is most
    /// likely to have already turned up. `@ScaledMetric` is what makes the
    /// number move (verified on device; `Font.system(size:)` does not).
    func themeFont(_ token: Theme.TypeToken) -> some View {
        modifier(ScaledFont(token))
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let face: String?
    private let weight: Font.Weight

    init(_ token: Theme.TypeToken) {
        _size = ScaledMetric(wrappedValue: token.size, relativeTo: token.relativeTo)
        face = token.face
        weight = token.weight
    }

    func body(content: Content) -> some View {
        content.font(font)
    }

    private var font: Font {
        // A bundled face carries its weight in the file — the static instances
        // exist precisely because SwiftUI's `.weight()` cannot drive a variable
        // font's `wght` axis. Asking for a weight here would silently do
        // nothing, or worse, synthesise a fake bold.
        if let face {
            .custom(face, size: size)
        } else {
            .system(size: size, weight: weight)
        }
    }
}
