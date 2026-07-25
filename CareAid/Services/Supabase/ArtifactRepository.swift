import Foundation
import Supabase

/// Reads `artifact` and records the caregiver's decision on one.
///
/// The rows themselves are created by the `extract` Edge Function (§7). The
/// only thing the app ever writes here is `status` — which is the whole of
/// CLAUDE.md §2, rule 3: nothing leaves the device without a human tap.
nonisolated struct ArtifactRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    func proposed() async throws -> [Artifact] {
        try await client
            .from("artifact")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .eq("status", value: ArtifactStatus.proposed.rawValue)
            .order("created_at", ascending: true)
            .decoded([Artifact].self)
    }

    func forCapture(_ captureID: UUID) async throws -> [Artifact] {
        try await client
            .from("artifact")
            .select()
            .eq("capture_id", value: captureID.uuidString)
            .order("created_at", ascending: true)
            .decoded([Artifact].self)
    }

    /// The question bank behind the Appointment Pack.
    func questions() async throws -> [Artifact] {
        try await client
            .from("artifact")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .eq("kind", value: ArtifactKind.question.rawValue)
            .in("status", values: [ArtifactStatus.approved.rawValue, ArtifactStatus.done.rawValue])
            .order("created_at", ascending: false)
            .decoded([Artifact].self)
    }

    func setStatus(_ status: ArtifactStatus, for id: UUID) async throws {
        try await client
            .from("artifact")
            .update([
                "status": status.rawValue,
                "actioned_at": Date.now.formatted(JSONCoding.fullTimestamp),
            ])
            .eq("id", value: id.uuidString)
            .execute()
    }
}
