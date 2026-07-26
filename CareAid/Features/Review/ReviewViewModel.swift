import Foundation
import Observation

/// Drives the Review sheet: what was recorded, what is being proposed, and what
/// she decides about each proposal.
///
/// Approving or dismissing writes `artifact.status` — the only column the app
/// ever writes (CLAUDE.md §7). C8 makes approval also *do* the thing.
@Observable
final class ReviewViewModel {

    enum Decision: Equatable {
        case pending
        case working
        case approved
        case dismissed
        case failed(String)
    }

    let response: ExtractionResponse
    let transcript: String

    /// True when the response came from `DemoData` because the backend was
    /// unreachable. Its artifacts have ids no row carries, so the status write
    /// is skipped — but the fan-out still runs, because the calendar entry, the
    /// WhatsApp draft and the reminders are all local and should genuinely
    /// happen.
    let isOffline: Bool

    private(set) var decisions: [UUID: Decision] = [:]
    var transcriptExpanded = false

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
}
