import Foundation
import Supabase

/// Reads `recipient`. One row in V0 — §10 rules out multiple care recipients.
nonisolated struct RecipientRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    func current() async throws -> Recipient? {
        try await client
            .from("recipient")
            .select()
            .eq("id", value: Config.recipientID.uuidString)
            .limit(1)
            .decoded([Recipient].self)
            .first
    }
}

/// Reads `caregiver`.
///
/// Holds more than the app user: Joy's row carries her visit windows, which is
/// what C12 clusters medication times around.
nonisolated struct CaregiverRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    /// Sarah — the person holding the phone.
    func currentUser() async throws -> Caregiver? {
        try await client
            .from("caregiver")
            .select()
            .eq("id", value: Config.caregiverID.uuidString)
            .limit(1)
            .decoded([Caregiver].self)
            .first
    }

    func all() async throws -> [Caregiver] {
        try await client
            .from("caregiver")
            .select()
            .order("name", ascending: true)
            .decoded([Caregiver].self)
    }
}

/// Reads `circle_member` — the people who can be told things.
nonisolated struct CircleMemberRepository {
    private let client: SupabaseClient

    init() throws {
        client = try Backend.requireClient()
    }

    func all() async throws -> [CircleMember] {
        try await client
            .from("circle_member")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .order("name", ascending: true)
            .decoded([CircleMember].self)
    }
}
