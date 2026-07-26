import SwiftUI

/// The navigation shell. Home is the root; everything else is one push deep,
/// which is the whole of CLAUDE.md §8's two-level cap.
struct RootView: View {
    @State private var appState = AppState()
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            NavigationStack(path: $appState.path) {
                HomeView()
                    .navigationDestination(for: Route.self, destination: destination)
            }

            if showingSplash {
                SplashView()
                    // Fades rather than cuts. Nothing on the splash moves, and
                    // nothing on Home moves to meet it — only the opacity does,
                    // so no text slides at the one moment she is orienting.
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(Theme.Motion.splashOut) { showingSplash = false }
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
