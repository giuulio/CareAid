import Foundation
import Observation

/// Drives one capture from typed text to a reviewed extraction.
///
/// The capture row is written *before* the LLM call, so a failed extraction
/// still leaves the note intact and visible (CLAUDE.md §8).
@Observable
final class CaptureViewModel {

    enum State {
        case composing
        case saving
        /// The slow one — 40 seconds or so. Shows her words back to her.
        case extracting(transcript: String)
        /// `capture` is non-nil once the note is safely stored, which decides
        /// what "try again" has to redo.
        case failed(capture: Capture?, message: String)
    }

    /// Handed to the Review sheet once extraction succeeds.
    struct Review: Identifiable {
        let id: UUID
        let response: ExtractionResponse
        let transcript: String
        /// True when this came from `DemoData` because the backend was
        /// unreachable. Its rows exist in no database, so approving must not
        /// try to PATCH them.
        var isOffline = false
    }

    var text: String = ""
    private(set) var state: State = .composing
    private(set) var review: Review?

    var canSend: Bool {
        if case .composing = state {
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    var isWorking: Bool {
        switch state {
        case .saving, .extracting: true
        case .composing, .failed: false
        }
    }

    func send() async {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }

        state = .saving
        do {
            let captures = try CaptureRepository()
            let capture = try await captures.create(source: .text, rawText: note)
            await extract(capture: capture, transcript: note)
        } catch {
            // Nothing was stored, so the text field is still the only copy —
            // leave it untouched so she can try again without retyping.
            state = .failed(capture: nil, message: error.localizedDescription)
        }
    }

    /// Retry means two different things depending on how far we got.
    func retry() async {
        if case .failed(let capture?, _) = state {
            // The note is already in Postgres. Re-running extraction on the
            // same capture_id replaces its rows rather than duplicating them,
            // so this is safe to press repeatedly.
            await extract(capture: capture, transcript: capture.rawText ?? text)
        } else {
            await send()
        }
    }

    /// Called when the Review sheet closes.
    func finishReview() {
        review = nil
        text = ""
        state = .composing
    }

    private func extract(capture: Capture, transcript: String) async {
        state = .extracting(transcript: transcript)
        do {
            let response = try await ExtractionService().extract(captureID: capture.id)
            review = Review(id: capture.id, response: response, transcript: transcript)
        } catch {
            if let fallback = OfflineFallback.review(for: transcript, error: error) {
                review = fallback
            } else {
                state = .failed(capture: capture, message: error.localizedDescription)
            }
        }
    }
}

/// The one place the demo fallback is decided, so both capture paths agree.
nonisolated enum OfflineFallback {

    /// A pre-baked review for the demo script when the backend is unreachable.
    ///
    /// Returns nil for anything else — an ordinary note that fails extraction
    /// must fail visibly (CLAUDE.md §8 keeps the raw text either way).
    static func review(for transcript: String, error: Error) -> CaptureViewModel.Review? {
        guard DemoData.resembles(transcript) else { return nil }

        // Loud on purpose. A shadow path that silently covers a real failure is
        // how a broken backend goes unnoticed until it matters.
        print("""
            [CareAid] ⚠️ EXTRACTION FAILED — falling back to the offline demo response.
                      This is the §9 script, so the Review sheet will still fill.
                      Reason: \(error.localizedDescription)
            """)

        return CaptureViewModel.Review(
            id: DemoData.extractionResponse.captureID,
            response: DemoData.extractionResponse,
            transcript: transcript,
            isOffline: true
        )
    }
}
