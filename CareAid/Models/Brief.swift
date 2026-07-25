import Foundation

/// The living document you hand the consultant. Versioned, never overwritten.
nonisolated struct Brief: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    var version: Int
    var content: BriefContent
    var generatedAt: Date?
    let sourceCaptureID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, version, content
        case recipientID = "recipient_id"
        case generatedAt = "generated_at"
        case sourceCaptureID = "source_capture_id"
    }
}

nonisolated struct BriefContent: Codable, Hashable, Sendable {
    /// The largest text in the app. One sentence, plain language.
    var oneLiner: String
    var currentConcerns: [Concern]
    var medications: [BriefMedication]
    var recentChanges: [String]
    var openQuestions: [String]
    var whatsWorking: [String]

    enum CodingKeys: String, CodingKey {
        case medications
        case oneLiner = "one_liner"
        case currentConcerns = "current_concerns"
        case recentChanges = "recent_changes"
        case openQuestions = "open_questions"
        case whatsWorking = "whats_working"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        oneLiner = try container.decodeIfPresent(String.self, forKey: .oneLiner) ?? ""
        currentConcerns = try container.decodeIfPresent([Concern].self, forKey: .currentConcerns) ?? []
        medications = try container.decodeIfPresent([BriefMedication].self, forKey: .medications) ?? []
        recentChanges = try container.decodeIfPresent([String].self, forKey: .recentChanges) ?? []
        openQuestions = try container.decodeIfPresent([String].self, forKey: .openQuestions) ?? []
        whatsWorking = try container.decodeIfPresent([String].self, forKey: .whatsWorking) ?? []
    }
}

nonisolated struct Concern: Codable, Hashable, Sendable {
    var text: String
    var since: PlainDate?
    var trend: Trend?
}

/// The brief's *narrative* view of a medication.
///
/// Distinct from `Medication`, which is the row the scheduler acts on. Keeping
/// them in step is exactly what the `medication_update` artifact is for.
nonisolated struct BriefMedication: Codable, Hashable, Sendable {
    var name: String
    var dose: String?
    var schedule: String?
    var adherenceNote: String?

    enum CodingKeys: String, CodingKey {
        case name, dose, schedule
        case adherenceNote = "adherence_note"
    }
}
