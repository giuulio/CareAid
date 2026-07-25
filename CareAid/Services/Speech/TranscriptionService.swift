import AVFoundation
import Foundation
import Observation
import Speech

/// Turns speech into text while she is still talking.
///
/// Apple's on-device recogniser is the whole implementation today. CLAUDE.md §3
/// names ElevenLabs Scribe as the primary with Apple as the fallback, and the
/// seam for that is `Provider` below — but the ordering is currently inverted
/// on purpose, because on-device costs nothing, needs no key, and cannot be
/// broken by conference wifi, which is exactly what C14 is afraid of.
@Observable
final class TranscriptionService {

    enum Provider: String {
        /// On device. No network, no key, no upload.
        case apple
        /// Needs ELEVENLABS_API_KEY as a Supabase secret, the `captures`
        /// Storage bucket, and the `transcribe` Edge Function — see
        /// EDGE_FUNCTIONS_PLAN.md. Not wired yet.
        case elevenLabs
    }

    enum TranscriptionError: LocalizedError {
        case speechDenied
        case unavailable
        case providerNotConfigured(Provider)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .speechDenied:
                "CareAid needs permission to turn speech into words. Settings › CareAid › Speech Recognition."
            case .unavailable:
                "Speech recognition isn't available on this phone right now."
            case .providerNotConfigured(let provider):
                "\(provider.rawValue) transcription isn't set up yet."
            case .failed(let detail):
                detail
            }
        }
    }

    /// Grows as she speaks, so the screen is never blank (§8).
    private(set) var transcript = ""
    private(set) var isListening = false

    private let recogniser = SFSpeechRecognizer(locale: Locale(identifier: "en_GB"))
    private var task: SFSpeechRecognitionTask?

    /// Touched from the audio thread. Apple documents `append(_:)` as safe to
    /// call from the recording tap, which is the entire point of an audio
    /// *buffer* request — so this is annotated unsafe rather than serialised.
    private nonisolated(unsafe) var request: SFSpeechAudioBufferRecognitionRequest?

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    func begin(provider: Provider = .apple) async throws {
        guard provider == .apple else { throw TranscriptionError.providerNotConfigured(provider) }
        guard await Self.requestPermission() else { throw TranscriptionError.speechDenied }
        guard let recogniser, recogniser.isAvailable else { throw TranscriptionError.unavailable }

        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on device. The simulator often can't, so allow the fallback
        // rather than refusing to work at all while developing.
        request.requiresOnDeviceRecognition = recogniser.supportsOnDeviceRecognition
        self.request = request

        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result { self.transcript = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true { self.isListening = false }
            }
        }
        isListening = true
    }

    /// Fed straight from the recorder's tap, on the audio thread.
    nonisolated func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    /// Closes the stream and waits briefly for the recogniser to settle, so the
    /// last few words she said actually make it in.
    func finish() async -> String {
        request?.endAudio()
        for _ in 0 ..< 20 where isListening {
            try? await Task.sleep(for: .milliseconds(100))
        }
        task?.finish()
        request = nil
        task = nil
        isListening = false
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancel() {
        task?.cancel()
        request = nil
        task = nil
        isListening = false
        transcript = ""
    }
}
