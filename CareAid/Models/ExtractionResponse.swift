import Foundation

/// What the extraction service returns after processing a capture.
///
/// Per the project specification (§7), events and artifacts have already been
/// written by the backend. The app decodes the response, displays the review
/// screen, and updates artifact status after the user's decision.
nonisolated struct ExtractionResponse: Codable, Hashable, Sendable {
    let captureID: UUID

    /// Auto-committed. Shown greyed and unactionable at the top of Review.
    let events: [TimelineEvent]

    /// All `proposed`. Each gets a card.
    let artifacts: [Artifact]

    /// Drives the banner above the cards. Not persisted separately.
    let patterns: [Pattern]

    /// Things the model was not certain enough about to guess.
    let flags: [Flag]

    /// The new brief version, if generated.
    let brief: Brief?

    enum CodingKeys: String, CodingKey {
        case events, artifacts, patterns, flags, brief
        case captureID = "capture_id"
    }

    /// Used for previews, static demo data and tests.
    ///
    /// Production responses continue to be decoded from backend JSON using
    /// `init(from:)`.
    init(
        captureID: UUID,
        events: [TimelineEvent],
        artifacts: [Artifact],
        patterns: [Pattern],
        flags: [Flag],
        brief: Brief?
    ) {
        self.captureID = captureID
        self.events = events
        self.artifacts = artifacts
        self.patterns = patterns
        self.flags = flags
        self.brief = brief
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        captureID = try container.decode(UUID.self, forKey: .captureID)
        events = try container.decodeIfPresent([TimelineEvent].self, forKey: .events) ?? []
        artifacts = try container.decodeIfPresent([Artifact].self, forKey: .artifacts) ?? []
        patterns = try container.decodeIfPresent([Pattern].self, forKey: .patterns) ?? []
        flags = try container.decodeIfPresent([Flag].self, forKey: .flags) ?? []
        brief = try container.decodeIfPresent(Brief.self, forKey: .brief)
    }
}

/// "That's the third missed evening dose this month."
///
/// Only possible because historical context exists in the system data.
nonisolated struct Pattern: Codable, Hashable, Sendable {
    var observation: String
    var evidenceEventIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case observation
        case evidenceEventIDs = "evidence_event_ids"
    }

    init(
        observation: String,
        evidenceEventIDs: [UUID] = []
    ) {
        self.observation = observation
        self.evidenceEventIDs = evidenceEventIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        observation = try container.decode(
            String.self,
            forKey: .observation
        )

        evidenceEventIDs = try container.decodeIfPresent(
            [UUID].self,
            forKey: .evidenceEventIDs
        ) ?? []
    }
}

/// Something ambiguous that needs clarification rather than an assumption.
nonisolated struct Flag: Codable, Hashable, Sendable {
    var type: FlagType

    /// The words that were unclear, e.g. "the 14th".
    var text: String?

    /// The clarification shown to the caregiver.
    var ask: String
}
