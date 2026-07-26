import SwiftUI

/// The card she said no to, turned into a microphone.
///
/// Deliberately in place rather than a new screen: she is looking at the thing
/// that is wrong, and it is the thing that should be listening. It also keeps
/// §8's no-modals rule — the Review sheet is already a full-screen cover, and
/// stacking another one on top of it is exactly the nesting that rule forbids.
///
/// Reads `model` directly so the waveform's forty-times-a-second updates
/// re-render this card and nothing else on the sheet.
struct CorrectionCard: View {
    let model: ReviewViewModel
    let headline: String
    let state: ReviewViewModel.Correction.State

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text(headline)
                    .themeFont(Theme.TypeScale.cardHeadline)
                    .foregroundStyle(Theme.Palette.ink)

                switch state {
                case .listening:
                    listening
                case .working(let words):
                    working(words)
                case .failed(let message):
                    failed(message)
                }
            }
        }
    }

    // MARK: - Listening

    private var listening: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text("Go on — tell me what it should say.")
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)

            Waveform(levels: model.levels)

            if !model.liveTranscript.isEmpty {
                Text(model.liveTranscript)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
            }

            PrimaryButton("That's it", systemImage: "checkmark") {
                Task { await model.finishCorrection() }
            }
            SecondaryButton("Leave it as it was") {
                model.cancelCorrection()
            }
        }
    }

    // MARK: - Working

    private func working(_ words: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            if !words.isEmpty {
                Text("“\(words)”")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
            }
            HStack(spacing: Theme.Space.m) {
                ProgressView()
                Text("Putting that right…")
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    // MARK: - Failed

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(message)
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
            SecondaryButton("Leave it as it was") {
                model.cancelCorrection()
            }
        }
    }
}
