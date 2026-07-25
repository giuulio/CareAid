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
            case .thinking(let transcript):
                thinking(transcript)
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
        .onDisappear { voice.cancel() }
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

    private func thinking(_ transcript: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Card {
                Text("“\(transcript)”")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.ink)
            }
            HStack(spacing: Theme.Space.m) {
                ProgressView()
                Text("Reading it back…")
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
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
        HStack(alignment: .center, spacing: Theme.Space.xs) {
            ForEach(0 ..< AudioRecorder.windowSize, id: \.self) { index in
                Capsule()
                    .fill(Theme.Palette.accent)
                    .frame(width: Theme.Space.xs, height: height(at: index))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Theme.Size.waveformHeight)
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
