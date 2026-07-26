import AVFoundation
import Foundation
import Observation
import Speech

/// Turns speech into text: Apple's recogniser live on screen while she talks,
/// and the `transcribe` Edge Function on the finished recording.
///
/// Both, in that order, on purpose:
///
///  * **Apple, live.** The words have to appear as she says them or the screen
///    reads as broken (§8). On device, no network, no key.
///  * **The server, on finish.** A general recogniser hears "co-careldopa" as
///    three unrelated words; `transcribe` sends her own medication list as a
///    vocabulary hint and gets it right. It is also the *only* thing that works
///    in the simulator, where Apple's recogniser returns nothing at all.
///
/// If the server is unreachable, Apple's live transcript is the answer and the
/// capture proceeds. Never lose input (§8).
@Observable
final class TranscriptionService {

    enum TranscriptionError: LocalizedError {
        case speechDenied
        case unavailable
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .speechDenied:
                "CareAid needs permission to turn speech into words. Settings › CareAid › Speech Recognition."
            case .unavailable:
                "Speech recognition isn't available on this phone right now."
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

    /// `nonisolated` is load-bearing, not tidiness.
    ///
    /// The target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so
    /// without it this closure is main-actor isolated — and `requestAuthorization`
    /// calls back on TCC's own queue, which trips `dispatch_assert_queue` and
    /// takes the app down the instant she taps the mic. Nothing here touches
    /// isolated state, so running off the main actor is correct as well as safe.
    nonisolated static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Starts the live, on-screen transcript.
    ///
    /// A recogniser that won't start is not fatal any more — the recording is
    /// still being written, and the server reads that. So this reports the
    /// problem and lets the caller decide, rather than ending the capture.
    func begin() async throws {
        guard await Self.requestPermission() else { throw TranscriptionError.speechDenied }
        guard let recogniser, recogniser.isAvailable else { throw TranscriptionError.unavailable }

        transcript = ""
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on device. The simulator often can't, so allow the fallback
        // rather than refusing to work at all while developing.
        request.requiresOnDeviceRecognition = recogniser.supportsOnDeviceRecognition
        self.request = request

        // `@Sendable` for the same reason `requestPermission` is `nonisolated`:
        // the recogniser calls back on its own queue, and a main-actor-isolated
        // closure would assert there. The hop below is what puts the words on
        // screen safely.
        task = recogniser.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let words = result?.bestTranscription.formattedString
            let finished = error != nil || result?.isFinal == true
            Task { @MainActor in
                guard let self else { return }
                if let words { self.transcript = words }
                if finished { self.isListening = false }
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

    // MARK: - The server

    /// Sends the recording to `transcribe` and returns what comes back.
    ///
    /// Empty is a legitimate answer — she may genuinely have said nothing — so
    /// this throws only when the round trip failed, which is what tells the
    /// caller to keep Apple's words instead.
    func transcribe(fileAt url: URL) async throws -> String {
        guard
            let root = Config.supabaseURL?.appendingPathComponent("functions/v1"),
            Config.isSupabaseConfigured
        else { throw BackendError.notConfigured }

        var request = URLRequest(url: root.appendingPathComponent("transcribe"))
        request.httpMethod = "POST"
        request.setValue(Self.contentType(of: url), forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        // Long enough for a minute of audio on hotel wifi, short enough that a
        // dead network doesn't hold the screen while she waits to be read back.
        request.timeoutInterval = 45

        // Reading audio changes nothing, so a dropped connection just gets sent
        // again rather than costing her the recording.
        let (data, response) = try await Backend.retryingTransient {
            try await URLSession.shared.upload(for: request, fromFile: url)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let reason = try? JSONDecoder().decode(ServerError.self, from: data)
            throw TranscriptionError.failed(reason?.error ?? "Transcription failed.")
        }
        let decoded = try JSONDecoder().decode(ServerTranscript.self, from: data)
        return decoded.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The server picks its decoder off this, so it has to match the file the
    /// recorder actually wrote.
    private static func contentType(of url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": "audio/wav"
        case "caf": "audio/x-caf"
        default: "audio/m4a"
        }
    }
}

private struct ServerTranscript: Decodable {
    let transcript: String
}

private struct ServerError: Decodable {
    let error: String
}
