import SwiftUI

/// Typing something in, for when she can't speak it aloud.
///
/// The whole screen exists to get one messy paragraph into the pipeline, so
/// there is exactly one primary action and nothing else to decide.
struct TextCaptureView: View {
    @Environment(AppState.self) private var appState
    @State private var model = CaptureViewModel()
    @FocusState private var editorFocused: Bool

    var body: some View {
        ScreenScaffold(title: "What happened?") {
            switch model.state {
            case .composing:
                composer
            case .saving:
                working("Saving your note…", transcript: nil)
            case .extracting(let transcript):
                working("Reading it back…", transcript: transcript)
            case .failed(let capture, let message):
                failed(capture: capture, message: message)
            }
        }
        .fullScreenCover(
            item: Binding(get: { model.review }, set: { if $0 == nil { finish() } })
        ) { review in
            ReviewView(response: review.response, transcript: review.transcript)
        }
        .onAppear { editorFocused = true }
    }

    // MARK: - Composing

    private var composer: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Text("Say it however it comes out. You don't have to be tidy.")
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)

            TextEditor(text: Binding(get: { model.text }, set: { model.text = $0 }))
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.ink)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: Theme.Size.textEditorMinHeight)
                .padding(Theme.Space.m)
                .background(Theme.Palette.surfaceRaised)
                .clipShape(.rect(cornerRadius: Theme.Radius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                        .strokeBorder(Theme.Palette.hairline, lineWidth: Theme.Size.hairline)
                }

            PrimaryButton("That's it", systemImage: "checkmark") {
                Task { await model.send() }
            }
            .opacity(model.canSend ? 1 : 0.4)
            .disabled(!model.canSend)
        }
    }

    // MARK: - Working

    /// Never a bare spinner — she sees her own words while it thinks
    /// (CLAUDE.md §8). Extraction takes about forty seconds.
    private func working(_ label: String, transcript: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            if let transcript {
                Card {
                    Text("“\(transcript)”")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.ink)
                }
            }
            HStack(spacing: Theme.Space.m) {
                ProgressView()
                Text(label)
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
    }

    // MARK: - Failed

    private func failed(capture: Capture?, message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text(capture == nil ? "Couldn't save that yet" : "Saved — but I couldn't read it")
                        .themeFont(Theme.TypeScale.cardHeadline)
                        .foregroundStyle(Theme.Palette.ink)
                    Text(capture == nil
                        ? "Your words are still here. Nothing has been lost."
                        : "Your note is safely stored. Only the reading-back failed.")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                    Text(message)
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }

            if let text = capture?.rawText {
                Card {
                    Text("“\(text)”")
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.ink)
                }
            }

            PrimaryButton("Try again", systemImage: "arrow.clockwise") {
                Task { await model.retry() }
            }
            SecondaryButton("Leave it for now") { finish() }
        }
    }

    private func finish() {
        model.finishReview()
        appState.path.removeAll()
    }
}

#Preview {
    RootView()
}
