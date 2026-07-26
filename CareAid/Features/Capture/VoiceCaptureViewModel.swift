import AVFoundation
import Foundation
import Observation

/// Recording, live transcription, then the same pipeline text capture uses.
///
/// The transcript is written to `capture` before the LLM call, exactly as in
/// C6 — the note survives a failed extraction (§8).
@Observable
final class VoiceCaptureViewModel {

    enum Phase {
        case listening
        /// Between "That's it" and having the words. Shows whatever the live
        /// recogniser managed, so the screen is never blank (§8).
        case writingDown(partial: String)
        case thinking(transcript: String)
        case failed(String)
    }

    private(set) var phase: Phase = .listening
    private(set) var review: CaptureViewModel.Review?

    private let recorder = AudioRecorder()
    private let speech = TranscriptionService()

    var levels: [Float] { recorder.levels }
    var transcript: String { speech.transcript }

    func start() async {
        // The recorder is what must start; the live recogniser is a nicety on
        // top of it. If speech recognition is unavailable — which is the normal
        // state of a simulator — we still record, and `transcribe` reads the
        // file when she's done.
        do {
            try await speech.begin()
            recorder.onBuffer = { @Sendable [speech] buffer in speech.append(buffer) }
        } catch {
            print("[CareAid] live transcript unavailable, recording anyway: \(error.localizedDescription)")
        }

        do {
            try await recorder.start()
            phase = .listening
        } catch {
            recorder.discard()
            speech.cancel()
            phase = .failed(error.localizedDescription)
        }
    }

    func finish() async {
        recorder.stop()
        let live = await speech.finish()
        phase = .writingDown(partial: live)

        let words = await bestTranscript(live: live)
        guard !words.isEmpty else {
            phase = .failed("I didn't catch anything. Try again, or type it instead.")
            return
        }

        phase = .thinking(transcript: words)
        do {
            let capture = try await CaptureRepository().create(source: .voice, rawText: words)
            let response = try await ExtractionService().extract(captureID: capture.id)
            review = CaptureViewModel.Review(
                id: capture.id, response: response, transcript: words
            )
        } catch {
            if let fallback = OfflineFallback.review(for: words, error: error) {
                review = fallback
                return
            }
            // The capture row may already exist; the words are on screen either
            // way, so nothing she said is lost.
            phase = .failed(error.localizedDescription)
        }
    }

    /// The server's reading of the recording, or Apple's live one if the round
    /// trip failed.
    ///
    /// Server first because it is the accurate one — it gets her medication
    /// names from her own record — and because in a simulator Apple's
    /// recogniser returns nothing at all. Falling back rather than failing is
    /// the §8 rule: whatever she said, something of it survives.
    private func bestTranscript(live: String) async -> String {
        guard let url = recorder.fileURL else { return live }
        do {
            let server = try await speech.transcribe(fileAt: url)
            if !server.isEmpty { return server }
            print("[CareAid] transcribe returned nothing; keeping the live transcript.")
        } catch {
            print("[CareAid] ⚠️ transcribe failed, falling back to the on-device transcript: "
                  + error.localizedDescription)
        }
        return live
    }

    func cancel() {
        recorder.discard()
        speech.cancel()
        review = nil
    }
}
