import SwiftUI

extension View {
    /// Applies a type token, scaled for Dynamic Type.
    ///
    /// Use this everywhere instead of `.font(...)`. SwiftUI's
    /// `Font.system(size:)` is fixed and ignores the user's text-size setting,
    /// which would quietly break CLAUDE.md §8 for exactly the reader we are
    /// building for.
    func themeFont(_ token: Theme.TypeToken) -> some View {
        modifier(ScaledFont(token))
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(_ token: Theme.TypeToken) {
        _size = ScaledMetric(wrappedValue: token.size, relativeTo: token.relativeTo)
        weight = token.weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}
