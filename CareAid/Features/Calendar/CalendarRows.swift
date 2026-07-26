import SwiftUI

/// One recorded entry, as a list row.
struct CalendarEventRow: View {
    let event: TimelineEvent
    /// Set for rows that sit outside the day being shown, e.g. "Coming up".
    var showsDay = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            Image(systemName: event.kind.symbol)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: Theme.Space.xl, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(event.headline)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
                if let detail = event.detail {
                    Text(detail)
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }

            Spacer(minLength: Theme.Space.s)

            Text(when)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
    }

    private var when: String {
        showsDay
            ? "\(DisplayDate.dayLabel(for: event.occurredAt)), \(DisplayDate.time(event.occurredAt))"
            : DisplayDate.time(event.occurredAt)
    }
}

/// One handover: a time, who is there for it, and everything due then.
struct DoseRow: View {
    let slot: ScheduleSlot

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
            Text(slot.time.display)
                .themeFont(Theme.TypeScale.bodyStrong)
                .foregroundStyle(Theme.Palette.ink)
                .monospacedDigit()

            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(names)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)

                Label(slot.coverage.plainDescription, systemImage: slot.coverage.symbol)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var names: String {
        slot.doses.map(\.medication.name).joined(separator: ", ")
    }
}

/// A timing collision. Never resolved for her — always asked about
/// (CLAUDE.md §2, rule 1).
struct ConflictRow: View {
    let conflict: ScheduleConflict
    let state: CalendarViewModel.AskState
    let ask: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(conflict.headline)
                .themeFont(Theme.TypeScale.bodyStrong)
                .foregroundStyle(Theme.Palette.ink)

            Text(conflict.detail)
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)

            if let citation = conflict.citation {
                Text("Label: “\(citation)”")
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }

            switch state {
            case .pending:
                Button("Add to my questions", systemImage: "questionmark.circle", action: ask)
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .buttonStyle(.borderless)
                    .frame(minHeight: Theme.Size.minTouchTarget, alignment: .leading)
            case .working:
                ProgressView()
            case .asked:
                Label("Added to your questions", systemImage: "checkmark.circle.fill")
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.accent)
            case .failed(let message):
                Text(message)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }
}

/// Why the day looks the way it does. Her diary being the input is the whole
/// idea, so it is said out loud rather than left implied.
struct YourDayFootnote: View {
    let schedule: ProposedSchedule
    let usedCalendar: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            if schedule.unavailable.isEmpty {
                Text("You're free all day.")
            }
            ForEach(schedule.unavailable, id: \.self) { block in
                Text("\(block.displayRange) · \(block.label ?? "Busy")")
            }
            ForEach(schedule.helperWindows, id: \.self) { block in
                Text("\(block.displayRange) · \(block.label ?? "Carer visit")")
            }
            Text(source)
            if schedule.isUnchanged {
                Text("Nothing needed moving — these are her prescribed times.")
            }
            Text(RuleStore.shared.disclaimer)
        }
        .themeFont(Theme.TypeScale.meta)
        .foregroundStyle(Theme.Palette.inkSecondary)
    }

    private var source: String {
        usedCalendar
            ? "From your working hours and your diary."
            : "From your working hours. Allow calendar access and CareAid will work around your diary too."
    }
}

/// The living brief, in the serif it is written in everywhere else.
struct BriefSummary: View {
    let brief: Brief

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(brief.content.oneLiner)
                .themeFont(Theme.TypeScale.document)
                .foregroundStyle(Theme.Palette.ink)

            ForEach(Array(brief.content.currentConcerns.enumerated()), id: \.offset) { _, concern in
                Label(concern.text, systemImage: symbol(for: concern.trend))
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }

    /// Direction of travel only. Never a severity or a judgement — rule 1.
    private func symbol(for trend: Trend?) -> String {
        switch trend {
        case .worsening: "arrow.up.right"
        case .improving: "arrow.down.right"
        case .stable, nil: "arrow.right"
        }
    }
}

/// "Make the pack", then "Send the pack" once it exists.
struct PackRow: View {
    let url: URL?
    let building: Bool
    let make: () -> Void

    var body: some View {
        if let url {
            ShareLink(item: url) {
                Label("Send the pack", systemImage: "square.and.arrow.up")
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .frame(minHeight: Theme.Size.minTouchTarget, alignment: .leading)
            }
        } else {
            Button(action: make) {
                Label(
                    building ? "Making it…" : "Make the pack",
                    systemImage: "doc.text"
                )
                .themeFont(Theme.TypeScale.bodyStrong)
                .frame(minHeight: Theme.Size.minTouchTarget, alignment: .leading)
            }
            .disabled(building)
        }
    }
}

/// A read that failed. Never a dead end — the mic still works.
struct CalendarNotice: View {
    let title: String
    let detail: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(title)
                .themeFont(Theme.TypeScale.bodyStrong)
                .foregroundStyle(Theme.Palette.ink)
            Text(detail)
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Button("Try again", systemImage: "arrow.clockwise", action: retry)
                .themeFont(Theme.TypeScale.bodyStrong)
                .buttonStyle(.borderless)
                .frame(minHeight: Theme.Size.minTouchTarget, alignment: .leading)
        }
        .padding(.vertical, Theme.Space.xs)
    }
}
