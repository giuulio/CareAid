import Foundation
import Supabase

/// Reads and updates `medication`.
///
/// The update path exists for one caller only: approving a `medication_update`
/// artifact (C8). Nothing else writes here — the Schedule screen's manual
/// override in C12 is the single other exception §10 allows.
nonisolated struct MedicationRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    func active() async throws -> [Medication] {
        try await client
            .from("medication")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .eq("active", value: true)
            .order("name", ascending: true)
            .decoded([Medication].self)
    }

    /// Applies one field of a reported change. `value` is sent as text and cast
    /// by Postgres, which keeps `active` and `quantity_remaining` working
    /// without a second code path.
    func update(id: UUID, field: MedicationField, to value: String) async throws {
        try await client
            .from("medication")
            .update([field.rawValue: value])
            .eq("id", value: id.uuidString)
            .execute()
    }
}
