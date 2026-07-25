import SwiftUI

/// Stub. Question bank and the PDF pack land in C10.
struct AppointmentPackView: View {
    var body: some View {
        ScreenScaffold(title: "Appointments") {
            Card {
                Text("Questions to ask, and a pack to take with you.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack { AppointmentPackView() }
}
