import Foundation
import Observation

/// Manages the state and actions for the Review screen
/// Handles which proposed artifacts are shown and tracks user decisions
@Observable
final class ReviewViewModel {

    private(set) var response: ExtractionResponse
    private(set) var dismissedArtifactIDs: Set<UUID> = []

    init(response: ExtractionResponse) {
        self.response = response
    }

    var visibleArtifacts: [Artifact] {
        response.artifacts.filter {
            !dismissedArtifactIDs.contains($0.id)
        }
    }

    func dismiss(_ artifact: Artifact) {
        dismissedArtifactIDs.insert(artifact.id)
    }

    func approve(_ artifact: Artifact) {
        // Backend PATCH will be connected here later
        // For the demo, approval is handled locally
    }

    func approveAll() {
        visibleArtifacts.forEach { approve($0) }
    }
}
