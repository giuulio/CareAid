import SwiftUI

/// Speak it. The screen shows the words arriving so it never looks stuck, and
/// cancel is always available (CLAUDE.md §8).
struct VoiceCaptureView: View {
    @Environment(AppState.self) private var appState
    @State private var voice = VoiceCaptureViewModel()

    var body: some View {
        ScreenScaffold(title: "I'm listening") {
            switch voice.phase {
            case .listening:
                listening
            case .writingDown(let partial):
                working("Writing it down…", symbol: "waveform", transcript: partial)
            case .thinking(let transcript):
                working("Reading it back…", symbol: "text.magnifyingglass", transcript: transcript)
            case .failed(let message):
                failed(message)
            }
        }
        .fullScreenCover(
            item: Binding(get: { voice.review }, set: { if $0 == nil { finish() } })
        ) { review in
            ReviewView(
                response: review.response,
                transcript: review.transcript,
                isOffline: review.isOffline
            )
        }
        .task { await voice.start() }
        // Only when there is nothing to review. `cancel()` clears `review`, and
        // `review` is what presents the sheet — so calling it once the sheet is
        // up dismisses her own results out from under her. This screen
        // disappears the moment the cover goes over it, and it disappears again
        // if she takes a call mid-correction.
        .onDisappear { if voice.review == nil { voice.cancel() } }
    }

    private var listening: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            Waveform(levels: voice.levels)

            Card {
                Text(voice.transcript.isEmpty ? "Go ahead — say what happened." : voice.transcript)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(
                        voice.transcript.isEmpty ? Theme.Palette.inkSecondary : Theme.Palette.ink
                    )
            }

            PrimaryButton("That's it", systemImage: "checkmark") {
                Task { await voice.finish() }
            }
            SecondaryButton("Cancel") { finish() }
        }
    }

    /// Never a bare spinner (§8). If the live recogniser caught nothing — a
    /// simulator, or a phone that declined speech recognition — say what is
    /// happening rather than showing an empty quote. The glyph changes with the
    /// stage, so the wait has visible shape even before the words are read.
    private func working(_ label: String, symbol: String, transcript: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Card {
                Text(transcript.isEmpty ? "I heard you. Getting the words down." : "“\(transcript)”")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(
                        transcript.isEmpty ? Theme.Palette.inkSecondary : Theme.Palette.ink
                    )
            }
            ThinkingIndicator(label: label, symbol: symbol)
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("That didn't work")
                        .themeFont(Theme.TypeScale.cardHeadline)
                        .foregroundStyle(Theme.Palette.ink)
                    Text(message)
                        .themeFont(Theme.TypeScale.body)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            PrimaryButton("Type it instead", systemImage: "keyboard") {
                appState.path = [.textCapture]
            }
            SecondaryButton("Go back") { finish() }
        }
    }

    private func finish() {
        voice.cancel()
        appState.path.removeAll()
    }
}

/// Live loudness. The one moving thing on this screen, and it exists so she
/// can tell the phone is actually hearing her.
struct Waveform: View {
    let levels: [Float]

    var body: some View {
        // Bars share the width they're given rather than each claiming a fixed
        // 4pt: forty-eight of those plus their gaps come to more than an iPhone
        // is wide, and an HStack that can't fit doesn't shrink — it overflows,
        // dragging every card on the page sideways with it. Only visible once
        // the waveform moved inside a card on the Review sheet.
        HStack(alignment: .center, spacing: Theme.Space.xs) {
            ForEach(0 ..< AudioRecorder.windowSize, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Palette.accentLit, Theme.Palette.accent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(maxWidth: Theme.Size.waveformBar)
                    .frame(height: height(at: index))
                    .animation(Theme.Motion.waveform, value: levels.count)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Theme.Size.waveformHeight)
        .accessibilityHidden(true)
    }

    private func height(at index: Int) -> CGFloat {
        // Right-aligned, so the newest sample is nearest the thumb.
        let offset = AudioRecorder.windowSize - levels.count
        let level = index >= offset ? levels[index - offset] : 0
        return max(Theme.Space.xs, CGFloat(level) * Theme.Size.waveformHeight)
    }
}

#Preview {
    RootView()
}
