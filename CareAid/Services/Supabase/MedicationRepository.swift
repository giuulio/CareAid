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

    /// Applies one field of a reported change.
    ///
    /// The model states every value as a string, but the columns underneath are
    /// `text`, `boolean`, `integer` and `time[]`. Sending a JSON string for all
    /// four leans on PostgREST casting it, which is version-dependent rather
    /// than guaranteed — so each field is typed on the way out.
    /// Returns the row as it now stands, and throws if there wasn't one.
    ///
    /// A PATCH that matches nothing is a *success* in PostgREST, so without this
    /// check a `medication_update` carrying an id the model got slightly wrong
    /// would flip its card to "Done" while her record stayed exactly as it was.
    /// A card that lies is worse than a card that fails.
    @discardableResult
    func update(id: UUID, field: MedicationField, to value: String) async throws -> Medication {
        let updated: [Medication] = try await client
            .from("medication")
            .update([field.rawValue: try Self.encode(value, for: field)])
            .eq("id", value: id.uuidString)
            .select()
            .decoded([Medication].self)

        guard let medication = updated.first else {
            throw MedicationUpdateError.noSuchMedication
        }
        return medication
    }

    /// Throws rather than guessing. A malformed value surfaces on the card as a
    /// failed approval, which is recoverable; a silently wrong `scheduled_times`
    /// is a reminder that fires at the wrong hour and nobody notices.
    static func encode(_ value: String, for field: MedicationField) throws -> AnyJSON {
        switch field {
        case .dose, .schedule:
            return .string(value)

        case .active:
            switch value.trimmingCharacters(in: .whitespaces).lowercased() {
            case "true", "yes", "1": return .bool(true)
            case "false", "no", "0": return .bool(false)
            default: throw MedicationUpdateError.notABoolean(value)
            }

        case .quantityRemaining:
            guard let number = Int(value.trimmingCharacters(in: .whitespaces)) else {
                throw MedicationUpdateError.notAWholeNumber(value)
            }
            return .integer(number)

        case .scheduledTimes:
            // Comma-separated `HH:MM`, in the order she'd read them out.
            let times = value.split(separator: ",").map(String.init)
            let parsed = times.compactMap(TimeOfDay.init)
            guard !parsed.isEmpty, parsed.count == times.count else {
                throw MedicationUpdateError.notTimes(value)
            }
            return .array(parsed.sorted().map { .string($0.description) })
        }
    }
}

nonisolated enum MedicationUpdateError: LocalizedError {
    case notABoolean(String)
    case notAWholeNumber(String)
    case notTimes(String)
    case noSuchMedication

    var errorDescription: String? {
        switch self {
        case .noSuchMedication:
            "That medicine isn't on her list, so nothing was changed."
        case .notABoolean(let value):
            "Couldn't read \"\(value)\" as yes or no, so her record wasn't changed."
        case .notAWholeNumber(let value):
            "Couldn't read \"\(value)\" as a number, so her record wasn't changed."
        case .notTimes(let value):
            "Couldn't read \"\(value)\" as times of day, so her record wasn't changed."
        }
    }
}
