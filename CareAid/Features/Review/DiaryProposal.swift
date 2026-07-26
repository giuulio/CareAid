import SwiftUI

/// The decision on a `calendar_event`: exactly what would be written, and an
/// explicit yes or no for writing it.
///
/// Two things are true of a diary entry that aren't true of the other cards.
/// It goes somewhere she owns and we don't — her phone's calendar, where a
/// wrong entry sits between a work meeting and the school run — so "no" has to
/// be as easy to hit as "yes", not a small line underneath the big button. And
/// what gets written is more than a headline: a time, a place, two alarms. She
/// can't edit a card before approving it (§10), so the card owes her the whole
/// of what she is agreeing to.
struct DiaryProposal: View {
    let payload: CalendarEventPayload
    let decision: ReviewViewModel.Decision
    let approveAction: () -> Void
    /// No, on this card, means the same as it does on every other one: we heard
    /// her wrong, and she is about to say it again. The mic glyph is on the
    /// button because a bare "No" that starts recording would be a surprise.
    let sayAgainAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            entry
            decisionArea
        }
    }

    // MARK: - What would be written

    private var entry: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            line(when, symbol: "clock")
            if let location = payload.location, !location.isEmpty {
                line(location, symbol: "mappin.and.ellipse")
            }
            if let reminders {
                line(reminders, symbol: "bell")
            }
            // Said out loud because it is the thing she is actually deciding:
            // recording it here needs no permission, putting it on her phone
            // does (§2, rules 3 and 4).
            line("Saved here and in your iPhone calendar", symbol: "iphone")
        }
    }

    private func line(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .themeFont(Theme.TypeScale.meta)
            .foregroundStyle(Theme.Palette.inkSecondary)
    }

    /// "Tomorrow, 14:30" · "14 August, 14:30 – 15:30"
    private var when: String {
        let day = DisplayDate.dayLabel(for: payload.startsAt)
        let start = DisplayDate.time(payload.startsAt)
        guard let endsAt = payload.endsAt else { return "\(day), \(start)" }
        return "\(day), \(start) – \(DisplayDate.time(endsAt))"
    }

    /// "Reminds you the day before and an hour before"
    private var reminders: String? {
        let phrases = payload.remindersMin.sorted(by: >).map(Self.phrase)
        guard !phrases.isEmpty else { return nil }
        return "Reminds you \(phrases.formatted(.list(type: .and)))"
    }

    private static func phrase(_ minutes: Int) -> String {
        switch minutes {
        case ...0: "when it starts"
        case ..<60: "\(minutes) minutes before"
        case 60: "an hour before"
        case ..<1440: "\(minutes / 60) hours before"
        case 1440: "the day before"
        default: "\(minutes / 1440) days before"
        }
    }

    // MARK: - Yes or no

    @ViewBuilder
    private var decisionArea: some View {
        switch decision {
        case .pending:
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Put it in the diary?")
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.ink)
                YesNoButtons(
                    yesSymbol: "calendar",
                    noSymbol: "mic",
                    yesAction: approveAction,
                    noAction: sayAgainAction
                )
            }

        case .working:
            WorkingLabel()

        case .approved:
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SettledLabel("It's in the diary", symbol: "checkmark.circle.fill")
                // The entry is hers now. This is the hand-off to where the rest
                // of her life already is — and the proof we didn't just say we
                // wrote it.
                SecondaryButton("See it in Calendar", systemImage: "arrow.up.forward.app") {
                    Task { await CalendarService.openSystemCalendar(on: payload.startsAt) }
                }
            }

        case .dismissed:
            SettledLabel("Left it", symbol: "xmark.circle.fill")

        case .failed(let message):
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(message)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                PrimaryButton("Try again", systemImage: "arrow.clockwise", action: approveAction)
                // Once she has said no to calendar access, asking again shows
                // nothing at all — the retry above would fail identically and
                // forever. Settings is the only way through, so offer it rather
                // than leaving her tapping a button that cannot work.
                if CalendarService.isDenied {
                    SecondaryButton("Open Settings", systemImage: "gear") {
                        Task { await CalendarService.openSettings() }
                    }
                }
            }
        }
    }
}

#Preview {
    DiaryProposal(
        payload: CalendarEventPayload(
            title: "Dr Okafor, neurology",
            startsAt: .now.addingTimeInterval(86_400),
            location: "Royal Infirmary, outpatients",
            notes: "Ask about the night-time freezing.",
            remindersMin: [1440, 60]
        ),
        decision: .pending,
        approveAction: {},
        sayAgainAction: {}
    )
    .padding(Theme.Space.l)
    .frame(maxHeight: .infinity)
    .background(Theme.Palette.surface)
}
