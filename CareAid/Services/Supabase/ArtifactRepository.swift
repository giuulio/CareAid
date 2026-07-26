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

    /// Diary entries she has said yes to.
    ///
    /// Approving a `calendar_event` writes her phone's calendar, and the row it
    /// came from is the *only* record CareAid keeps of it — nothing in §6 copies
    /// an approved proposal into `timeline_event`. Without reading these back,
    /// an appointment she just put in the diary is invisible on the app's own
    /// calendar screen, which is the one place she'd look for it.
    func diaryEntries() async throws -> [Artifact] {
        try await client
            .from("artifact")
            .select()
            .eq("recipient_id", value: Config.recipientID.uuidString)
            .eq("kind", value: ArtifactKind.calendarEvent.rawValue)
            .in("status", values: [ArtifactStatus.approved.rawValue, ArtifactStatus.done.rawValue])
            .order("created_at", ascending: false)
            .decoded([Artifact].self)
    }

    /// Raises a question the scheduler found, as a normal proposal.
    ///
    /// The one insert the app performs. §7 gives the Edge Function ownership of
    /// every *extraction* write, and this is not one — nothing was extracted,
    /// no model was called, and there is no capture behind it. A medication
    /// timing conflict is noticed on device by `MedicationScheduler`, and per
    /// §2 rule 1 the only thing it may produce is a question for a pharmacist.
    ///
    /// `capture_id` is null: "see what I said" has nothing to show, because she
    /// didn't say anything — we noticed.
    @discardableResult
    func propose(question: QuestionPayload) async throws -> Artifact {
        try await client
            .from("artifact")
            .insert(NewQuestion(
                recipientID: Config.recipientID,
                payload: question
            ))
            .select()
            .single()
            // An insert is not safe to send twice — see `retryingTransient`.
            .decoded(Artifact.self, retryOnDrop: false)
    }

    func setStatus(_ status: ArtifactStatus, for id: UUID) async throws {
        try await client
            .from("artifact")
            .update([
                "status": status.rawValue,
                "actioned_at": Date.now.formatted(JSONCoding.fullTimestamp),
            ])
            .eq("id", value: id.uuidString)
            .executed()
    }
}

/// The insert shape. `status` is hardcoded `proposed` rather than passed in —
/// nothing this app writes may arrive already approved (§2, rule 3).
private nonisolated struct NewQuestion: Encodable {
    let recipientID: UUID
    let payload: QuestionPayload
    let kind = ArtifactKind.question.rawValue
    let status = ArtifactStatus.proposed.rawValue

    enum CodingKeys: String, CodingKey {
        case payload, kind, status
        case recipientID = "recipient_id"
    }
}
