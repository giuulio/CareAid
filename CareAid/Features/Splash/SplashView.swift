import SwiftUI

/// One second of who this is for, including the fade before the mic takes over.
///
/// The line matters more than the mark. Every other app in this space opens by
/// naming the patient; this one opens by naming *her*, and that is the whole
/// product argument in five words. It is also the only place in the app the
/// argument gets made — Home is a question and a button, and rightly has no
/// room for a mission statement.
///
/// Nothing on the splash moves. It holds briefly, then fades; something that
/// moved would still be moving when it left.
struct SplashView: View {
    let onFinished: () -> Void
    @State private var didStartDismissalTimer = false

    init(onFinished: @escaping () -> Void = {}) {
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            Theme.Palette.surface.ignoresSafeArea()

            VStack(spacing: Theme.Space.xl) {
                BrandMark(size: Theme.Size.brandMark)

                VStack(spacing: Theme.Space.s) {
                    Text("CareAid")
                        .themeFont(Theme.TypeScale.splashTitle)
                        .foregroundStyle(Theme.Palette.ink)

                    Text("Supporting you, the caregiver")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Theme.Space.xl)
        }
        // One announcement for VoiceOver, which will still be reading it as the
        // screen goes — better than three fragments that get cut off.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("CareAid. Supporting you, the caregiver.")
        .task {
            guard !didStartDismissalTimer else { return }
            didStartDismissalTimer = true
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(1000))
            onFinished()
        }
    }
}

#Preview {
    SplashView()
}
