import SwiftUI

/// The demo's centrepiece. One messy paragraph became this.
///
/// Order matters: what she said, then any pattern that reframes it, then what
/// was already recorded, then what needs a decision.
struct ReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ReviewViewModel
    @State private var appeared = false

    init(response: ExtractionResponse, transcript: String = "", isOffline: Bool = false) {
        _model = State(initialValue: ReviewViewModel(
            response: response, transcript: transcript, isOffline: isOffline
        ))
    }

    var body: some View {
        ZStack {
            Theme.Palette.surface.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    transcriptCard

                    if !model.patterns.isEmpty {
                        PatternBanner(patterns: model.patterns).staggered(0, appeared)
                    }

                    ForEach(Array(model.flags.enumerated()), id: \.offset) { index, flag in
                        FlagNotice(flag: flag, transcript: model.transcript)
                            .staggered(index + 1, appeared)
                    }

                    ForEach(Array(model.events.enumerated()), id: \.element.id) { index, event in
                        RecordedEntry(event: event)
                            .staggered(index + model.flags.count + 1, appeared)
                    }

                    ForEach(Array(model.artifacts.enumerated()), id: \.element.id) { index, artifact in
                        ReviewCard(
                            artifact: artifact,
                            decision: model.decision(for: artifact),
                            approveAction: { Task { await model.approve(artifact) } },
                            dismissAction: { Task { await model.dismiss(artifact) } }
                        )
                        .staggered(index + model.events.count + model.flags.count + 1, appeared)
                    }

                    footer
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.vertical, Theme.Space.xl)
            }
        }
        .task {
            // The one animation in the app, used once (CLAUDE.md §8).
            withAnimation(.easeOut(duration: 0.2)) { appeared = true }
        }
    }

    // MARK: - Pieces

    private var transcriptCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("What I heard")
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)

                if model.transcript.isEmpty {
                    Text("No transcript for this one.")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                } else {
                    Text("“\(model.transcript)”")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                        .lineLimit(model.transcriptExpanded ? nil : 3)

                    // Rule 6: every output on this screen traces back to here.
                    SecondaryButton(
                        model.transcriptExpanded ? "Hide what I said" : "See what I said",
                        systemImage: model.transcriptExpanded ? "chevron.up" : "chevron.down"
                    ) {
                        model.transcriptExpanded.toggle()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: Theme.Space.m) {
            if model.hasUndecided && model.artifacts.count > 1 {
                PrimaryButton("Approve all", systemImage: "checkmark.circle") {
                    Task { await model.approveAll() }
                }
            }
            SecondaryButton(model.hasUndecided ? "Leave the rest" : "Done") { dismiss() }
        }
        .padding(.top, Theme.Space.s)
    }
}

private extension View {
    /// 200ms, offset a little per card so the stack lands rather than snaps.
    func staggered(_ index: Int, _ appeared: Bool) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : Theme.Space.xl)
            .animation(
                .easeOut(duration: 0.2).delay(Double(index) * 0.04),
                value: appeared
            )
    }
}
