import SwiftUI

/// One proposal, with one large thing to do and one small way to decline.
///
/// The action label is the *outcome* in her words — "Tell Tom", not "Send
/// family update" (CLAUDE.md §8).
struct ReviewCard: View {
    let artifact: Artifact
    let decision: ReviewViewModel.Decision
    let approveAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text(headline)
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)

                Text(detail)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)

                if let why {
                    Text(why)
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }

                decisionArea
            }
        }
    }

    @ViewBuilder
    private var decisionArea: some View {
        switch decision {
        case .pending:
            VStack(spacing: Theme.Space.s) {
                PrimaryButton(actionLabel, systemImage: symbol, action: approveAction)
                SecondaryButton("Not this", action: dismissAction)
            }
        case .working:
            HStack(spacing: Theme.Space.s) {
                ProgressView()
                Text("Just a moment…")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(height: Theme.Size.secondaryButtonHeight)
        case .approved:
            settled("Done", symbol: "checkmark.circle.fill")
        case .dismissed:
            settled("Left it", symbol: "xmark.circle.fill")
        case .failed(let message):
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(message)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
                PrimaryButton("Try again", systemImage: "arrow.clockwise", action: approveAction)
            }
        }
    }

    private func settled(_ label: String, symbol: String) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: symbol)
                .themeFont(Theme.TypeScale.icon)
            Text(label)
                .themeFont(Theme.TypeScale.bodyStrong)
        }
        .foregroundStyle(Theme.Palette.accent)
        .frame(height: Theme.Size.secondaryButtonHeight)
    }

    // MARK: - Copy, per kind

    private var headline: String {
        switch artifact.payload {
        case .task: "Something to do"
        case .calendarEvent: "For the diary"
        case .familyUpdate(let p): "Tell \(p.toName)"
        case .question: "To ask at the appointment"
        case .timer: "A reminder"
        case .medicationUpdate: "Update her record"
        }
    }

    private var detail: String {
        switch artifact.payload {
        case .task(let p): p.title
        case .calendarEvent(let p):
            "\(p.title) — \(DisplayDate.dayLabel(for: p.startsAt)), \(DisplayDate.time(p.startsAt))"
        case .familyUpdate(let p): "“\(p.draftText)”"
        case .question(let p): p.question
        case .timer(let p): "\(p.label) — \(DisplayDate.time(p.fireAt))"
        case .medicationUpdate(let p):
            "\(p.medicationName): \(p.field.rawValue) becomes \(p.to)"
        }
    }

    /// The model's reason, where it has one. Shown small — it is context, not
    /// the decision she is making.
    private var why: String? {
        switch artifact.payload {
        case .task(let p): p.why
        case .medicationUpdate(let p): p.why
        default: nil
        }
    }

    private var actionLabel: String {
        switch artifact.payload {
        case .task: "Remind me"
        case .calendarEvent: "Put it in the diary"
        case .familyUpdate(let p): "Tell \(p.toName)"
        case .question: "Add to my questions"
        case .timer: "Set the reminder"
        case .medicationUpdate: "Update her record"
        }
    }

    private var symbol: String {
        switch artifact.payload {
        case .task: "bell"
        case .calendarEvent: "calendar"
        case .familyUpdate: "paperplane"
        case .question: "stethoscope"
        case .timer: "timer"
        case .medicationUpdate: "pills"
        }
    }
}
