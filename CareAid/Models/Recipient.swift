import Foundation

/// The person being cared for. Margaret Ellis, in our seed data.
nonisolated struct Recipient: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    /// What the caregiver calls them — "Mum".
    var displayName: String
    var legalName: String?
    var yearOfBirth: Int?
    var conditions: [String]
    var allergies: [String]
    var gpPractice: String?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case legalName = "legal_name"
        case yearOfBirth = "year_of_birth"
        case conditions
        case allergies
        case gpPractice = "gp_practice"
        case createdAt = "created_at"
    }
}

/// The person holding the phone. Sarah, in our seed data.
nonisolated struct Caregiver: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var relation: String?
    /// Caregiver-first: what C12 schedules medication *around*.
    var workHours: WorkHours
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, relation
        case workHours = "work_hours"
        case createdAt = "created_at"
    }
}

/// Recurring blocks when the caregiver is not available to hand over pills.
///
/// §6 leaves `work_hours jsonb` undefined; this is the shape we commit to.
/// Labelled blocks cover both "Mon–Fri 09:00–17:30" and "standup 09:00–09:30"
/// without needing two different fields.
nonisolated struct WorkHours: Codable, Hashable, Sendable {
    nonisolated struct Block: Codable, Hashable, Sendable {
        var label: String
        var days: [Weekday]
        var start: TimeOfDay
        var end: TimeOfDay
    }

    var blocks: [Block]

    init(blocks: [Block] = []) {
        self.blocks = blocks
    }

    /// Tolerates the `{}` default in the schema.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks = try container.decodeIfPresent([Block].self, forKey: .blocks) ?? []
    }
}

/// Someone who gets updates. Tom, in Manchester.
nonisolated struct CircleMember: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    var name: String
    var relation: String?
    var channel: Channel
    var handle: String?
    var shareLevel: ShareLevel

    enum CodingKeys: String, CodingKey {
        case id, name, relation, channel, handle
        case recipientID = "recipient_id"
        case shareLevel = "share_level"
    }
}
