import Foundation

/// A record of something that happened.
///
/// The one thing that writes without asking — recording needs no permission,
/// acting does (CLAUDE.md §2, rule 4).
nonisolated struct TimelineEvent: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    /// What Sarah said that produced this. Drives "see what I said".
    let captureID: UUID?
    var kind: TimelineEventKind
    var occurredAt: Date
    /// ≤ 60 characters, plain English.
    var headline: String
    var detail: String?
    var severity: Severity
    var tags: [String]
    var confidence: Double?

    enum CodingKeys: String, CodingKey {
        case id, kind, headline, detail, severity, tags, confidence
        case recipientID = "recipient_id"
        case captureID = "capture_id"
        case occurredAt = "occurred_at"
    }
}
