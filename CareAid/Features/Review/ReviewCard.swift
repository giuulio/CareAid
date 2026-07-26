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
        case .medicationUpdate(let p): "A change to her \(p.medicationName)"
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
        case .medicationUpdate(let p): Self.change(p)
        }
    }

    /// A reported change, in the words she'd use — never the column name.
    private static func change(_ payload: MedicationUpdatePayload) -> String {
        let from = payload.from.map { "was \($0)" }
        let line: String = switch payload.field {
        case .dose: "Dose becomes \(payload.to)"
        case .schedule: "Now \(payload.to)"
        case .scheduledTimes: "Times become \(payload.to.replacingOccurrences(of: ",", with: ", "))"
        case .active: payload.to.lowercased() == "false" ? "Stopped" : "Started again"
        case .quantityRemaining: "\(payload.to) left in the box"
        }
        return [line, from].compactMap { $0 }.joined(separator: " — ")
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
