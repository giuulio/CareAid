import SwiftUI

/// Half a second of who this is for, before the mic takes over.
///
/// The line matters more than the mark. Every other app in this space opens by
/// naming the patient; this one opens by naming *her*, and that is the whole
/// product argument in five words. It is also the only place in the app the
/// argument gets made — Home is a question and a button, and rightly has no
/// room for a mission statement.
///
/// Nothing animates. It is on screen for 500ms; something that moved would
/// still be moving when it left.
struct SplashView: View {
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
    }
}

#Preview {
    SplashView()
}
