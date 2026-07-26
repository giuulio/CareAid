import Foundation
import Observation

/// Drives the Review sheet: what was recorded, what is being proposed, what she
/// decides about each proposal — and, when we got one wrong, her saying it again.
///
/// Approving or dismissing writes `artifact.status` — the only column the app
/// ever writes (CLAUDE.md §7).
@Observable
final class ReviewViewModel {

    enum Decision: Equatable {
        case pending
        case working
        case approved
        case dismissed
        case failed(String)
    }

    /// Her re-recording a card we got wrong, in place on that card.
    struct Correction {
        let artifactID: UUID

        enum State: Equatable {
            case listening
            /// Her new words, while the model reads them back.
            case working(String)
            case failed(String)
        }
        var state: State = .listening
    }

    /// Replaced wholesale when a correction lands, so the screen only ever
    /// shows one version of the truth.
    private(set) var response: ExtractionResponse
    private(set) var transcript: String

    /// True when the response came from `DemoData` because the backend was
    /// unreachable. Its artifacts have ids no row carries, so the status write
    /// is skipped — but the fan-out still runs, because the calendar entry, the
    /// WhatsApp draft and the reminders are all local and should genuinely
    /// happen.
    let isOffline: Bool

    private(set) var decisions: [UUID: Decision] = [:]
    private(set) var correction: Correction?
    var transcriptExpanded = false

    private let recorder = AudioRecorder()
    private let speech = TranscriptionService()

    init(response: ExtractionResponse, transcript: String = "", isOffline: Bool = false) {
        self.response = response
        self.transcript = transcript
        self.isOffline = isOffline
    }

    /// Proposals stay on screen after a decision — she should see what she just
    /// did, not watch cards vanish from under her thumb.
    var artifacts: [Artifact] { response.artifacts }

    var events: [TimelineEvent] { response.events }

    var patterns: [Pattern] { response.patterns }

    /// Anything the model wasn't sure enough about to act on (§7 rule 2), plus
    /// possible escalations (rule 6). Both need to be seen, not buried.
    var flags: [Flag] { response.flags }

    func decision(for artifact: Artifact) -> Decision {
        decisions[artifact.id] ?? .pending
    }

    var hasUndecided: Bool {
        artifacts.contains { decision(for: $0) == .pending }
    }

    /// Live while she is correcting one.
    var levels: [Float] { recorder.levels }
    var liveTranscript: String { speech.transcript }

    // MARK: - Deciding

    /// Do the thing first, then record that it happened. If the calendar write
    /// or the permission prompt fails, the card stays undecided rather than
    /// claiming success she'd only discover was false later.
    func approve(_ artifact: Artifact) async {
        decisions[artifact.id] = .working
        do {
            try await FanOutService().perform(artifact, isOffline: isOffline)
            try await record(.approved, for: artifact)
            decisions[artifact.id] = .approved
        } catch {
            decisions[artifact.id] = .failed(error.localizedDescription)
        }
    }

    func dismiss(_ artifact: Artifact) async {
        decisions[artifact.id] = .working
        do {
            try await record(.dismissed, for: artifact)
            decisions[artifact.id] = .dismissed
        } catch {
            decisions[artifact.id] = .failed(error.localizedDescription)
        }
    }

    /// Writes the decision, unless there is no row to write it to.
    private func record(_ status: ArtifactStatus, for artifact: Artifact) async throws {
        guard !isOffline else { return }
        try await ArtifactRepository().setStatus(status, for: artifact.id)
    }

    func approveAll() async {
        for artifact in artifacts where decision(for: artifact) == .pending {
            await approve(artifact)
        }
    }

    // MARK: - Saying it again

    /// "Not quite — say it again", on a card that came out wrong.
    ///
    /// Rejecting is not the end of the road: the card she said no to is the
    /// single most useful piece of context for getting it right, so it goes to
    /// the model along with her new words rather than into a bin.
    func startCorrection(of artifact: Artifact) async {
        correction = Correction(artifactID: artifact.id)
        do {
            try? await speech.begin()
            recorder.onBuffer = { @Sendable [speech] buffer in speech.append(buffer) }
            try await recorder.start()
        } catch {
            correction?.state = .failed(error.localizedDescription)
        }
    }

    func cancelCorrection() {
        recorder.discard()
        speech.cancel()
        correction = nil
    }

    /// Stops recording, reads it back with the rejected card as context, and
    /// swaps the whole sheet for the corrected version.
    func finishCorrection() async {
        guard let correcting = correction else { return }

        recorder.stop()
        let live = await speech.finish()
        correction?.state = .working(live)

        let words = await bestTranscript(live: live)
        guard !words.isEmpty else {
            correction?.state = .failed("I didn't catch that. Try once more.")
            return
        }
        correction?.state = .working(words)

        do {
            let capture = try await CaptureRepository().create(source: .voice, rawText: words)
            let corrected = try await ExtractionService().extract(
                captureID: capture.id,
                correcting: CareAid.Correction(
                    captureID: response.captureID,
                    rejectedArtifactIDs: [correcting.artifactID]
                )
            )
            await clearOldProposals(except: correcting.artifactID)

            response = corrected
            transcript = words
            decisions = [:]
            correction = nil
        } catch {
            correction?.state = .failed(error.localizedDescription)
        }
    }

    /// The old sheet is about to disappear, and its proposals with it. Anything
    /// still sitting at `proposed` would be stranded in the database with no
    /// screen to decide it on — the model has been told to re-propose whatever
    /// still stands, so these are closed off here.
    private func clearOldProposals(except rejected: UUID) async {
        guard !isOffline else { return }
        for artifact in artifacts where decision(for: artifact) == .pending {
            try? await ArtifactRepository().setStatus(.dismissed, for: artifact.id)
        }
        try? await ArtifactRepository().setStatus(.dismissed, for: rejected)
    }

    /// Server first, Apple's live words if the round trip fails — the same
    /// order the capture screens use.
    private func bestTranscript(live: String) async -> String {
        guard let url = recorder.fileURL else { return live }
        do {
            let server = try await speech.transcribe(fileAt: url)
            if !server.isEmpty { return server }
        } catch {
            print("[CareAid] ⚠️ correction transcribe failed, using the on-device words: "
                  + error.localizedDescription)
        }
        return live
    }
}
