import SwiftUI

/// Stub. Real seeded events land in C4, the brief card in C10.
struct TimelineView: View {
    var body: some View {
        ScreenScaffold(title: "Timeline") {
            Card {
                Text("Everything recorded about Mum will appear here, newest first.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack { TimelineView() }
}
