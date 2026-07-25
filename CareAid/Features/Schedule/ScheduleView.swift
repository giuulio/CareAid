import SwiftUI

/// Stub. Medication times, conflicts and the caregiver's busy blocks land in C12.
struct ScheduleView: View {
    var body: some View {
        ScreenScaffold(title: "Schedule") {
            Card {
                Text("Mum's medication times, arranged around your day.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack { ScheduleView() }
}
