import Foundation

/// What the `extract` Edge Function returns after it has written everything.
///
/// Per CLAUDE.md §7 the function owns every extraction write, so these events
/// and artifacts are already persisted and carry real database ids. The app
/// decodes, renders the Review sheet, and PATCHes `artifact.status` on
/// approval — it never inserts.
nonisolated struct ExtractionResponse: Codable, Hashable, Sendable {
    let captureID: UUID
    /// Auto-committed. Shown greyed and unactionable at the top of Review.
    let events: [TimelineEvent]
    /// All `proposed`. Each gets a card.
    let artifacts: [Artifact]
    /// Drives the banner above the cards. No table — transient.
    let patterns: [Pattern]
    /// Things the model was not sure enough about to guess. No table.
    let flags: [Flag]
    /// The new brief version, if `brief_patch` produced one.
    let brief: Brief?

    enum CodingKeys: String, CodingKey {
        case events, artifacts, patterns, flags, brief
        case captureID = "capture_id"
    }

    init(
        captureID: UUID,
        events: [TimelineEvent] = [],
        artifacts: [Artifact] = [],
        patterns: [Pattern] = [],
        flags: [Flag] = [],
        brief: Brief? = nil
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
/// Only possible because seeded history exists — CLAUDE.md §9.
nonisolated struct Pattern: Codable, Hashable, Sendable {
    var observation: String
    var evidenceEventIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case observation
        case evidenceEventIDs = "evidence_event_ids"
    }

    init(observation: String, evidenceEventIDs: [UUID] = []) {
        self.observation = observation
        self.evidenceEventIDs = evidenceEventIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        observation = try container.decode(String.self, forKey: .observation)
        evidenceEventIDs = try container.decodeIfPresent([UUID].self, forKey: .evidenceEventIDs) ?? []
    }
}

/// Something ambiguous. Per §7 rule 2, low confidence produces one of these
/// rather than a guess.
nonisolated struct Flag: Codable, Hashable, Sendable {
    var type: FlagType
    /// The words that were unclear, e.g. "the 14th".
    var text: String?
    /// What to put to the caregiver, e.g. "Is the neurology appointment 14 August?"
    var ask: String
}
