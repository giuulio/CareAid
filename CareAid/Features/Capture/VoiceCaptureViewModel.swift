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
        do {
            try await speech.begin()
            recorder.onBuffer = { [speech] buffer in speech.append(buffer) }
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
        let words = await speech.finish()

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
            // The capture row may already exist; the words are on screen either
            // way, so nothing she said is lost.
            phase = .failed(error.localizedDescription)
        }
    }

    func cancel() {
        recorder.discard()
        speech.cancel()
        review = nil
    }
}
