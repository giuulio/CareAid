import Foundation
import Supabase

/// Reads `brief`. Versions are never overwritten, so "current" is just the
/// highest version number.
nonisolated struct BriefRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    func current() async throws -> Brief? {
        let briefs: [Brief] = try await client
            .from("brief")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .order("version", ascending: false)
            .limit(1)
            .decoded([Brief].self)
        return briefs.first
    }
}
