import Foundation

/// One prescribed medication.
///
/// This row is what the Schedule screen and the C12 scheduler read, and what
/// an approved `medication_update` artifact writes.
nonisolated struct Medication: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientID: UUID
    var name: String
    var rxcui: String?
    var dose: String?
    /// Human-readable, e.g. "4x daily: 8am, 12pm, 4pm, 8pm".
    var schedule: String?
    /// The machine-readable version of `schedule`.
    var scheduledTimes: [TimeOfDay]
    var quantityRemaining: Int?
    var startedOn: PlainDate?
    var active: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, rxcui, dose, schedule, active
        case recipientID = "recipient_id"
        case scheduledTimes = "scheduled_times"
        case quantityRemaining = "quantity_remaining"
        case startedOn = "started_on"
    }
}
