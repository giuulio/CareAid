import Foundation
import Supabase

/// Writes and reads `capture` — the raw thing Sarah said.
///
/// The insert happens *before* the LLM call, so a failed extraction still
/// leaves the note intact and visible (CLAUDE.md §8, "never lose input").
nonisolated struct CaptureRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    /// Only the columns we set. `captured_at` and `id` are defaulted by
    /// Postgres, which conveniently means nothing here needs date encoding.
    private struct NewCapture: Encodable {
        let recipient_id: String
        let author_id: String
        let source: String
        let raw_text: String?
    }

    @discardableResult
    func create(source: CaptureSource, rawText: String?) async throws -> Capture {
        let row = NewCapture(
            recipient_id: Config.recipientID.uuidString,
            author_id: Config.caregiverID.uuidString,
            source: source.rawValue,
            raw_text: rawText
        )
        return try await client
            .from("capture")
            .insert(row)
            .select()
            .single()
            .decoded(Capture.self)
    }

    func find(id: UUID) async throws -> Capture? {
        try await client
            .from("capture")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .decoded([Capture].self)
            .first
    }
}
