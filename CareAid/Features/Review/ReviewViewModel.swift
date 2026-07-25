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

    private(set) var decisions: [UUID: Decision] = [:]
    var transcriptExpanded = false

    init(response: ExtractionResponse, transcript: String = "") {
        self.response = response
        self.transcript = transcript
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
            try await FanOutService().perform(artifact)
            try await ArtifactRepository().setStatus(.approved, for: artifact.id)
            decisions[artifact.id] = .approved
        } catch {
            decisions[artifact.id] = .failed(error.localizedDescription)
        }
    }

    func dismiss(_ artifact: Artifact) async {
        decisions[artifact.id] = .working
        do {
            try await ArtifactRepository().setStatus(.dismissed, for: artifact.id)
            decisions[artifact.id] = .dismissed
        } catch {
            decisions[artifact.id] = .failed(error.localizedDescription)
        }
    }

    func approveAll() async {
        for artifact in artifacts where decision(for: artifact) == .pending {
            await approve(artifact)
        }
    }

    private func setStatus(
        _ status: ArtifactStatus,
        for artifact: Artifact,
        then outcome: Decision
    ) async {
        decisions[artifact.id] = .working
        do {
            try await ArtifactRepository().setStatus(status, for: artifact.id)
            decisions[artifact.id] = outcome
        } catch {
            decisions[artifact.id] = .failed(error.localizedDescription)
        }
    }
}
