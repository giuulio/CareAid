import SwiftUI

/// The navigation shell. Home is the root; everything else is one push deep,
/// which is the whole of CLAUDE.md §8's two-level cap.
struct RootView: View {
    @State private var appState = AppState()

    var body: some View {
        NavigationStack(path: $appState.path) {
            HomeView()
                .navigationDestination(for: Route.self, destination: destination)
        }
        .environment(appState)
        .tint(Theme.Palette.accent)
        .preferredColorScheme(Theme.preferredColorScheme())
        // Type scales, but not without limit: our base sizes already sit well
        // above the system default, and the largest settings break side-by-side
        // layouts outright. Raise or drop this in C13 once real content exists.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .voiceCapture:
            VoiceCaptureView()
        case .textCapture:
            TextCaptureView()
        case .calendar:
            CalendarView()
        case .medications:
            MedicationsView()
        #if DEBUG
        case .demoReview:
            // isOffline: these rows are not in the database, so decisions must
            // not try to PATCH them — same path the wifi fallback uses.
            ReviewView(
                response: DemoData.extractionResponse,
                transcript: DemoData.transcript,
                isOffline: true
            )
        #endif
        }
    }
}

#Preview {
    RootView()
}
