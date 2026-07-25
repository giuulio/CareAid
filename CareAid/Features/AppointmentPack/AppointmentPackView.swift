import SwiftUI

/// Everything she wants to raise, and one button to turn it into something she
/// can hand over.
struct AppointmentPackView: View {
    @State private var model = AppointmentPackViewModel()

    var body: some View {
        ScreenScaffold(title: "Appointments") {
            switch model.state {
            case .loading:
                Card {
                    Text("Getting your questions together…")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            case .failed(let message):
                failed(message)
            case .ready:
                ready
            }
        }
        .task { await model.load() }
    }

    private func failed(_ message: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("Couldn't load this")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                Text(message)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                PrimaryButton("Try again", systemImage: "arrow.clockwise") {
                    Task { await model.load() }
                }
            }
        }
    }

    @ViewBuilder
    private var ready: some View {
        if let appointment = model.nextAppointment {
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Next appointment")
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    Text(appointment.headline)
                        .themeFont(Theme.TypeScale.cardHeadline)
                        .foregroundStyle(Theme.Palette.ink)
                    Text("\(DisplayDate.dayLabel(for: appointment.occurredAt)), \(DisplayDate.time(appointment.occurredAt))")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
        }

        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("What you wanted to ask")
                .themeFont(Theme.TypeScale.cardHeadline)
                .foregroundStyle(Theme.Palette.inkSecondary)

            if model.questionTexts.isEmpty {
                Card {
                    Text("Nothing yet. When you mention something you want to raise, it'll appear here.")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            } else {
                ForEach(Array(model.questionTexts.enumerated()), id: \.offset) { _, question in
                    Card {
                        Text(question)
                            .themeFont(Theme.TypeScale.body)
                            .foregroundStyle(Theme.Palette.ink)
                    }
                }
            }
        }

        packActions
    }

    @ViewBuilder
    private var packActions: some View {
        VStack(spacing: Theme.Space.m) {
            if let url = model.packURL {
                // ShareLink can't take a PrimaryButton label, so this mirrors
                // its styling from the same tokens rather than hardcoding.
                ShareLink(item: url) {
                    HStack(spacing: Theme.Space.m) {
                        Image(systemName: "square.and.arrow.up")
                            .themeFont(Theme.TypeScale.icon)
                        Text("Send the pack")
                    }
                    .themeFont(Theme.TypeScale.button)
                    .foregroundStyle(Theme.Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Size.primaryButtonHeight)
                    .background(Theme.Palette.accent)
                    .clipShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
                }
                SecondaryButton("Make it again", systemImage: "arrow.clockwise") {
                    Task { await model.makePack() }
                }
            } else {
                PrimaryButton(
                    model.buildingPack ? "Making it…" : "Make the pack",
                    systemImage: "doc.text"
                ) {
                    Task { await model.makePack() }
                }
                .disabled(model.buildingPack)
            }
        }
        .padding(.top, Theme.Space.s)
    }
}

#Preview {
    NavigationStack { AppointmentPackView() }
}
