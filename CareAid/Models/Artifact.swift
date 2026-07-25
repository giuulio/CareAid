import Foundation

/// Something CareAid proposes doing. Never acted on without a tap
/// (CLAUDE.md §2, rule 3).
nonisolated struct Artifact: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    /// Drives "see what I said" on every card.
    let captureID: UUID?
    var payload: ArtifactPayload
    var status: ArtifactStatus
    var confidence: Double?
    var createdAt: Date?
    var actionedAt: Date?

    /// Derived, never stored separately — `kind` and `payload` cannot disagree.
    var kind: ArtifactKind { payload.kind }

    enum CodingKeys: String, CodingKey {
        case id, kind, payload, status, confidence
        case recipientID = "recipient_id"
        case captureID = "capture_id"
        case createdAt = "created_at"
        case actionedAt = "actioned_at"
    }

    init(
        id: UUID,
        recipientID: UUID,
        captureID: UUID?,
        payload: ArtifactPayload,
        status: ArtifactStatus,
        confidence: Double? = nil,
        createdAt: Date? = nil,
        actionedAt: Date? = nil
    ) {
        self.id = id
        self.recipientID = recipientID
        self.captureID = captureID
        self.payload = payload
        self.status = status
        self.confidence = confidence
        self.createdAt = createdAt
        self.actionedAt = actionedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recipientID = try container.decode(UUID.self, forKey: .recipientID)
        captureID = try container.decodeIfPresent(UUID.self, forKey: .captureID)
        status = try container.decode(ArtifactStatus.self, forKey: .status)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        actionedAt = try container.decodeIfPresent(Date.self, forKey: .actionedAt)

        // `payload` is jsonb with six possible shapes, and the discriminator is
        // a sibling key rather than a parent. So: read `kind` first, then pick.
        let kind = try container.decode(ArtifactKind.self, forKey: .kind)
        payload = try ArtifactPayload(from: container, kind: kind)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recipientID, forKey: .recipientID)
        try container.encodeIfPresent(captureID, forKey: .captureID)
        try container.encode(kind, forKey: .kind)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(actionedAt, forKey: .actionedAt)
        try payload.encode(to: &container, forKey: .payload)
    }
}

/// The six shapes `artifact.payload` can take.
///
/// An enum rather than a dictionary so C8's fan-out gets a compiler error when
/// a case is left unhandled, instead of a silent nil at 3am.
nonisolated enum ArtifactPayload: Hashable, Sendable {
    case task(TaskPayload)
    case calendarEvent(CalendarEventPayload)
    case familyUpdate(FamilyUpdatePayload)
    case question(QuestionPayload)
    case timer(TimerPayload)
    case medicationUpdate(MedicationUpdatePayload)

    var kind: ArtifactKind {
        switch self {
        case .task: .task
        case .calendarEvent: .calendarEvent
        case .familyUpdate: .familyUpdate
        case .question: .question
        case .timer: .timer
        case .medicationUpdate: .medicationUpdate
        }
    }

    fileprivate init(
        from container: KeyedDecodingContainer<Artifact.CodingKeys>,
        kind: ArtifactKind
    ) throws {
        let key = Artifact.CodingKeys.payload
        self = switch kind {
        case .task: .task(try container.decode(TaskPayload.self, forKey: key))
        case .calendarEvent: .calendarEvent(try container.decode(CalendarEventPayload.self, forKey: key))
        case .familyUpdate: .familyUpdate(try container.decode(FamilyUpdatePayload.self, forKey: key))
        case .question: .question(try container.decode(QuestionPayload.self, forKey: key))
        case .timer: .timer(try container.decode(TimerPayload.self, forKey: key))
        case .medicationUpdate: .medicationUpdate(try container.decode(MedicationUpdatePayload.self, forKey: key))
        }
    }

    fileprivate func encode(
        to container: inout KeyedEncodingContainer<Artifact.CodingKeys>,
        forKey key: Artifact.CodingKeys
    ) throws {
        switch self {
        case .task(let payload): try container.encode(payload, forKey: key)
        case .calendarEvent(let payload): try container.encode(payload, forKey: key)
        case .familyUpdate(let payload): try container.encode(payload, forKey: key)
        case .question(let payload): try container.encode(payload, forKey: key)
        case .timer(let payload): try container.encode(payload, forKey: key)
        case .medicationUpdate(let payload): try container.encode(payload, forKey: key)
        }
    }
}

// MARK: - Payloads

nonisolated struct TaskPayload: Codable, Hashable, Sendable {
    var title: String
    var dueAt: Date?
    /// Why this is being suggested. Shown on the card.
    var why: String

    enum CodingKeys: String, CodingKey {
        case title, why
        case dueAt = "due_at"
    }
}

nonisolated struct CalendarEventPayload: Codable, Hashable, Sendable {
    var title: String
    var startsAt: Date
    var endsAt: Date?
    var location: String?
    var notes: String?
    /// Minutes before the event, e.g. `[1440, 60]`.
    var remindersMin: [Int]

    enum CodingKeys: String, CodingKey {
        case title, location, notes
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case remindersMin = "reminders_min"
    }

    init(
        title: String,
        startsAt: Date,
        endsAt: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        remindersMin: [Int] = []
    ) {
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.location = location
        self.notes = notes
        self.remindersMin = remindersMin
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        startsAt = try container.decode(Date.self, forKey: .startsAt)
        endsAt = try container.decodeIfPresent(Date.self, forKey: .endsAt)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        remindersMin = try container.decodeIfPresent([Int].self, forKey: .remindersMin) ?? []
    }
}

nonisolated struct FamilyUpdatePayload: Codable, Hashable, Sendable {
    var toCircleMemberID: UUID?
    /// The resolved name, so the card reads "Tell Tom" without a join.
    var toName: String
    var channel: Channel
    /// Three sentences maximum, in Sarah's register.
    var draftText: String

    enum CodingKeys: String, CodingKey {
        case channel
        case toCircleMemberID = "to_circle_member_id"
        case toName = "to_name"
        case draftText = "draft_text"
    }
}

nonisolated struct QuestionPayload: Codable, Hashable, Sendable {
    var question: String
    var forSpecialty: String?
    var priority: Int?

    enum CodingKeys: String, CodingKey {
        case question, priority
        case forSpecialty = "for_specialty"
    }
}

nonisolated struct TimerPayload: Codable, Hashable, Sendable {
    var label: String
    var fireAt: Date
    var repeats: String?

    enum CodingKeys: String, CodingKey {
        case label
        case fireAt = "fire_at"
        case repeats = "repeat"
    }
}

/// A medication change the caregiver *reported*.
///
/// Never something we inferred — see CLAUDE.md §7, prompt rule 8. `why` is
/// attribution ("Sarah said Dr Okafor increased it"), never rationale.
nonisolated struct MedicationUpdatePayload: Codable, Hashable, Sendable {
    var medicationID: UUID
    /// Carried so the card renders without a join, and so a mis-resolved id
    /// can be spotted before anything is written.
    var medicationName: String
    var field: MedicationField
    var from: String?
    var to: String
    var why: String

    enum CodingKeys: String, CodingKey {
        case field, from, to, why
        case medicationID = "medication_id"
        case medicationName = "medication_name"
    }
}
