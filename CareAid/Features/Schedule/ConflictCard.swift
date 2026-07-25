import SwiftUI

/// A timing conflict, and the one thing CareAid is allowed to do about it.
///
/// There is no "fix it" button here, and there never will be. CLAUDE.md §2
/// rule 1: where medication timing conflicts, the output is a question for a
/// pharmacist or GP — never an instruction, never a changed time.
struct ConflictCard: View {
    let conflict: ScheduleConflict
    let state: ScheduleViewModel.AskState
    let ask: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Label {
                    Text(conflict.headline)
                        .themeFont(Theme.TypeScale.cardHeadline)
                        .foregroundStyle(Theme.Palette.ink)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .themeFont(Theme.TypeScale.icon)
                        .foregroundStyle(Theme.Palette.accent)
                }

                Text(conflict.detail)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)

                if let citation = conflict.citation {
                    citationView(citation)
                }

                action
            }
        }
    }

    /// Quoted, never paraphrased — it is the difference between reference data
    /// and us appearing to have an opinion.
    private func citationView(_ citation: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("From the label")
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Text("“\(citation)”")
                .themeFont(Theme.TypeScale.meta)
                .foregroundStyle(Theme.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.m)
        .background(Theme.Palette.accentSoft)
        .clipShape(.rect(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var action: some View {
        switch state {
        case .pending:
            PrimaryButton(askLabel, systemImage: "questionmark.bubble", action: ask)

        case .working:
            HStack(spacing: Theme.Space.m) {
                ProgressView()
                Text("Adding it…")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(height: Theme.Size.primaryButtonHeight)

        case .asked:
            Label("Added to your questions", systemImage: "checkmark.circle.fill")
                .themeFont(Theme.TypeScale.bodyStrong)
                .foregroundStyle(Theme.Palette.accent)
                .frame(height: Theme.Size.minTouchTarget)

        case .failed(let message):
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(message)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.ink)
                PrimaryButton("Try again", systemImage: "arrow.clockwise", action: ask)
            }
        }
    }

    /// Whose question it is. A label rule is a pharmacist's; a dose nobody can
    /// be there for is the surgery's.
    private var askLabel: String {
        conflict.question.forSpecialty?.caseInsensitiveCompare("Pharmacy") == .orderedSame
            ? "Ask the pharmacist"
            : "Ask the surgery"
    }
}
