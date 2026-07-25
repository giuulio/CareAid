import Foundation

/// Turns an approved artifact into the real thing.
///
/// This is the moment CareAid stops being a notebook. Everything here runs
/// *only* after a tap (CLAUDE.md §2, rule 3), and the enum means the compiler
/// catches any kind that hasn't been given a destination.
@MainActor
struct FanOutService {

    /// Performs the action. Throws if the thing genuinely didn't happen, so the
    /// card can stay undecided rather than claiming success.
    func perform(_ artifact: Artifact) async throws {
        // Only a proposal can be acted on. The one caller today sources its
        // artifacts from `ArtifactRepository.proposed()` so this never fires,
        // but a stale `Artifact` value handed back here later would otherwise
        // re-open WhatsApp or rewrite the diary without anyone asking.
        guard artifact.status == .proposed else { return }

        switch artifact.payload {
        case .calendarEvent(let payload):
            try await CalendarService().add(payload, artifactID: artifact.id)

        case .familyUpdate(let payload):
            let handle = try await handle(for: payload)
            try await MessageService().compose(payload, handle: handle)

        case .task(let payload):
            try await ReminderService().schedule(task: payload, id: artifact.id)

        case .timer(let payload):
            try await ReminderService().schedule(timer: payload, id: artifact.id)

        case .medicationUpdate(let payload):
            try await MedicationRepository().update(
                id: payload.medicationID, field: payload.field, to: payload.to
            )

        case .question:
            // Nothing to fire. Approving a question *is* the action — it lands
            // in the bank the Appointment Pack reads (C10), which is just the
            // status write the caller already does.
            break
        }
    }

    /// The model resolves the name; we still look up the number ourselves
    /// rather than trusting a phone number to come back from an LLM.
    private func handle(for payload: FamilyUpdatePayload) async throws -> String? {
        let members = try await CircleMemberRepository().all()
        if let id = payload.toCircleMemberID,
           let match = members.first(where: { $0.id == id }) {
            return match.handle
        }
        return members.first { $0.name.caseInsensitiveCompare(payload.toName) == .orderedSame }?
            .handle
    }
}
