import SwiftUI

/// Mum's medication times, arranged around Sarah's day.
///
/// The differentiator, on one screen: her work, her commute and her real diary
/// are constraints, not decoration. Where they collide with a label rule the
/// screen shows a question, never a fix.
struct ScheduleView: View {
    @State private var model = ScheduleViewModel()

    var body: some View {
        ScreenScaffold(title: "Schedule") {
            switch model.state {
            case .loading:
                loading
            case .loaded:
                loaded
            case .failed(let message):
                failed(message)
            }
        }
        .task { await model.load() }
    }

    // MARK: - States

    private var loading: some View {
        Card {
            HStack(spacing: Theme.Space.m) {
                ProgressView()
                Text("Working out her day…")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    private func failed(_ message: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Can't show her schedule")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)
                Text(message)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var loaded: some View {
        if let schedule = model.schedule {
            yourDay(schedule)

            // Conflicts first. They are the only thing on this screen that
            // wants a decision.
            ForEach(schedule.conflicts) { conflict in
                ConflictCard(conflict: conflict, state: model.askState(for: conflict)) {
                    Task { await model.ask(conflict) }
                }
            }

            ForEach(schedule.slots) { slot in
                ScheduleSlotRow(slot: slot)
            }

            footnote(schedule)
        }
    }

    // MARK: - Pieces

    /// Why the schedule looks the way it does. Shown first, because her day
    /// being the input is the whole idea.
    private func yourDay(_ schedule: ProposedSchedule) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Your day — \(DisplayDate.dayLabel(for: model.day))")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)

                if schedule.unavailable.isEmpty {
                    // Says it rather than showing a gap. On a Saturday Sarah
                    // genuinely is free, and an empty list would read as a bug.
                    Text("You're free all day.")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.ink)
                }
                ForEach(schedule.unavailable, id: \.self) { block in
                    line(block.displayRange, block.label ?? "Busy", symbol: "briefcase")
                }
                ForEach(schedule.helperWindows, id: \.self) { block in
                    line(block.displayRange, block.label ?? "Carer visit", symbol: "hands.and.sparkles")
                }

                Text(source)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                    .padding(.top, Theme.Space.xs)
            }
        }
    }

    /// Where the constraints came from — so "you're free all day" reads as a
    /// finding rather than as us not having looked.
    private var source: String {
        model.usedCalendar
            ? "From your working hours and today's diary."
            : "From your working hours. Allow calendar access and CareAid will work around today's diary too."
    }

    private func line(_ range: String, _ label: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            Image(systemName: symbol)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.accent)
            Text(range)
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.ink)
            Text(label)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Spacer(minLength: 0)
        }
    }

    /// Says out loud both that nothing was changed and where the rules came
    /// from. Both matter: this screen must never read as medical advice.
    private func footnote(_ schedule: ProposedSchedule) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if schedule.isUnchanged {
                Text("Nothing needed moving — these are her prescribed times.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
            }
            Text(RuleStore.shared.disclaimer)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { ScheduleView() }
}
