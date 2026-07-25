import SwiftUI

/// Standard page frame: warm background, consistent gutters, optional title.
///
/// Every screen goes through this so padding never drifts between features.
struct ScreenScaffold<Content: View>: View {
    private let title: String?
    private let fillsHeight: Bool
    private let content: Content

    /// - Parameter fillsHeight: `true` when the layout uses `Spacer`s to
    ///   distribute content down the whole screen (Home). The page still
    ///   scrolls once type gets large enough to overflow — content is never
    ///   squeezed until it truncates.
    init(title: String? = nil, fillsHeight: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.fillsHeight = fillsHeight
        self.content = content()
    }

    var body: some View {
        ZStack {
            Theme.Palette.surface.ignoresSafeArea()

            if fillsHeight {
                GeometryReader { proxy in
                    ScrollView {
                        page.frame(minHeight: proxy.size.height)
                    }
                }
            } else {
                ScrollView { page }
            }
        }
        .toolbarBackground(Theme.Palette.surface, for: .navigationBar)
    }

    private var page: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            if let title {
                Text(title)
                    .themeFont(Theme.TypeScale.screenTitle)
                    .foregroundStyle(Theme.Palette.ink)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.xl)
    }
}

#Preview {
    NavigationStack {
        ScreenScaffold(title: "Timeline") {
            Card {
                Text("Placeholder")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
            }
        }
    }
}
