import Foundation
import Supabase

/// Reads `timeline_event`.
///
/// There is deliberately no insert for extraction output: per CLAUDE.md §7 the
/// `extract` Edge Function writes those rows itself and returns them. The app
/// reads them back.
nonisolated struct TimelineRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    /// Everything that has already happened, newest first.
    func recent(limit: Int = 200) async throws -> [TimelineEvent] {
        try await client
            .from("timeline_event")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .lte("occurred_at", value: Date.now.formatted(JSONCoding.fullTimestamp))
            .order("occurred_at", ascending: false)
            .limit(limit)
            .decoded([TimelineEvent].self)
    }

    /// Appointments and anything else still ahead of us, soonest first.
    func upcoming(limit: Int = 5) async throws -> [TimelineEvent] {
        try await client
            .from("timeline_event")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .gt("occurred_at", value: Date.now.formatted(JSONCoding.fullTimestamp))
            .order("occurred_at", ascending: true)
            .limit(limit)
            .decoded([TimelineEvent].self)
    }
}
