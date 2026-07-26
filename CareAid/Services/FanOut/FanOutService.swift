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
    ///
    /// - Parameter isOffline: true when the artifact came from `DemoData`
    ///   because the backend was unreachable. Everything local still happens —
    ///   the diary entry, the WhatsApp draft, the reminder are all real — but
    ///   the writes that need Postgres are skipped rather than failing a card
    ///   for a row that exists in no database.
    func perform(_ artifact: Artifact, isOffline: Bool = false) async throws {
        // Only a proposal can be acted on. The one caller today sources its
        // artifacts from `ArtifactRepository.proposed()` so this never fires,
        // but a stale `Artifact` value handed back here later would otherwise
        // re-open WhatsApp or rewrite the diary without anyone asking.
        //
        // Throwing rather than returning quietly: a silent no-op here would let
        // the card flip to "Done" having done nothing, which is the one outcome
        // worse than a visible failure.
        guard artifact.status == .proposed else {
            throw FanOutError.alreadyDecided
        }

        switch artifact.payload {
        case .calendarEvent(let payload):
            try await CalendarService().add(payload, artifactID: artifact.id)

        case .familyUpdate(let payload):
            let handle = try await handle(for: payload, isOffline: isOffline)
            try await MessageService().compose(payload, handle: handle)

        case .task(let payload):
            try await ReminderService().schedule(task: payload, id: artifact.id)

        case .timer(let payload):
            try await ReminderService().schedule(timer: payload, id: artifact.id)

        case .medicationUpdate(let payload):
            // Nothing to write to when the database is what's missing. Saying
            // "done" here is honest: the change she reported is on the card in
            // front of her, and the row it belongs to isn't reachable.
            guard !isOffline else { return }
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
    ///
    /// With no backend there is no circle to look in, so the demo's own numbers
    /// stand in — otherwise the one card the whole pitch turns on dies with
    /// "there's no phone number saved for them".
    private func handle(for payload: FamilyUpdatePayload, isOffline: Bool) async throws -> String? {
        guard !isOffline else { return DemoData.handle(for: payload.toName) }
        let members = try await CircleMemberRepository().all()
        if let id = payload.toCircleMemberID,
           let match = members.first(where: { $0.id == id }) {
            return match.handle
        }
        return members.first { $0.name.caseInsensitiveCompare(payload.toName) == .orderedSame }?
            .handle
    }
}

nonisolated enum FanOutError: LocalizedError {
    case alreadyDecided

    var errorDescription: String? {
        switch self {
        case .alreadyDecided:
            "You've already decided about this one."
        }
    }
}
