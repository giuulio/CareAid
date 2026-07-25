import Foundation

/// One thing Sarah said, exactly as she said it.
///
/// Written *before* the LLM call. If extraction fails the raw note survives
/// and stays visible — CLAUDE.md §8, "never lose input".
nonisolated struct Capture: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    let authorID: UUID?
    let source: CaptureSource
    var rawText: String?
    var mediaURL: String?
    var capturedAt: Date
    /// Stamped by the `extract` Edge Function when it finishes writing.
    var processedAt: Date?

    // `model_raw` is intentionally absent. It stores the unparsed LLM response
    // for debugging and for recovering patterns/flags; the app never reads it,
    // and modelling arbitrary jsonb here would buy nothing.

    enum CodingKeys: String, CodingKey {
        case id, source
        case recipientID = "recipient_id"
        case authorID = "author_id"
        case rawText = "raw_text"
        case mediaURL = "media_url"
        case capturedAt = "captured_at"
        case processedAt = "processed_at"
    }
}
