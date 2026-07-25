import Foundation

/// Medication timing rules read off real DailyMed labels.
///
/// Generated offline by `tools/dailymed_extract.py` and shipped in the bundle,
/// because CLAUDE.md §3 will not let the demo depend on a third-party API being
/// reachable. Nothing here calls the network.
///
/// **Reference data, never advice.** A rule is a fact printed on a label, and
/// every one of them carries the sentence it was read out of so it can be
/// quoted rather than paraphrased. When two rules collide the answer is a
/// question for a pharmacist — never a changed schedule (§2, rule 1).
nonisolated struct RuleStore: Sendable {

    static let shared = RuleStore()

    private let document: RulesDocument?

    /// Loads once. A missing or malformed file is survivable: the scheduler
    /// falls back to "no label constraints", which is honest rather than wrong.
    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "medication_rules", withExtension: "json") else {
            #if DEBUG
            print("[CareAid] medication_rules.json is not in the bundle — no label rules will apply.")
            #endif
            document = nil
            return
        }
        do {
            document = try JSONDecoder().decode(RulesDocument.self, from: Data(contentsOf: url))
        } catch {
            #if DEBUG
            print("[CareAid] medication_rules.json failed to decode: \(error)")
            #endif
            document = nil
        }
    }

    /// Shown wherever rules are surfaced, so the framing travels with the data.
    var disclaimer: String { document?.disclaimer ?? "" }

    func entry(for medication: Medication) -> MedicationRuleEntry? {
        guard let medications = document?.medications else { return nil }
        // RxCUI first — names are display strings and drift. The seed has no
        // rxcui yet, so in practice this falls through to the name today.
        if let rxcui = medication.rxcui, !rxcui.isEmpty,
           let match = medications.first(where: { $0.rxcui == rxcui }) {
            return match
        }
        return medications.first {
            $0.name.caseInsensitiveCompare(medication.name) == .orderedSame
        }
    }

    func rules(for medication: Medication) -> [MedicationRule] {
        entry(for: medication)?.rules ?? []
    }

    /// True when we looked and the label genuinely had nothing to say, as
    /// opposed to us never having looked. The Schedule screen says so out loud
    /// rather than implying a medication is unconstrained.
    func isUnresolved(_ medication: Medication) -> Bool {
        entry(for: medication)?.unresolved != nil
    }
}

// MARK: - The shipped file

nonisolated struct RulesDocument: Codable, Sendable {
    var source: String
    var disclaimer: String
    var medications: [MedicationRuleEntry]
}

nonisolated struct MedicationRuleEntry: Codable, Hashable, Sendable {
    /// Matches `medication.name` in the seed exactly.
    var name: String
    var rxcui: String?
    /// The DailyMed SPL this came from — the citation's other half.
    var setid: String?
    var splTitle: String?
    /// Set where a UK product was looked up under a US equivalent, so the
    /// substitution is visible rather than silent.
    var mappingNote: String?
    /// Set when the label had no usable administration section. Distinct from
    /// an empty `rules` array, which means the section existed and said nothing
    /// about timing.
    var unresolved: String?
    var rules: [MedicationRule]

    enum CodingKeys: String, CodingKey {
        case name, rxcui, setid, unresolved, rules
        case splTitle = "spl_title"
        case mappingNote = "mapping_note"
    }
}

nonisolated struct MedicationRule: Codable, Hashable, Sendable {
    var type: RuleType
    /// Verbatim from the label. Displayed, never paraphrased.
    var sourceSentence: String
    /// Only present on rules that state a number, e.g. a 4-hour separation.
    var hours: Double?

    enum CodingKeys: String, CodingKey {
        case type, hours
        case sourceSentence = "source_sentence"
    }
}

/// Open on purpose, like `FlagType`: the extraction script can learn a new
/// pattern without the app failing to decode the whole file.
nonisolated struct RuleType: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }

    /// Take on an empty stomach — constrains this to before a meal.
    static let emptyStomach = RuleType(rawValue: "empty_stomach")
    /// Take with food.
    static let withFood = RuleType(rawValue: "with_food")
    /// Keep this many hours away from other medications.
    static let separation = RuleType(rawValue: "separation")
    /// Protein interferes with absorption.
    static let avoidProtein = RuleType(rawValue: "avoid_protein")
    /// Take at the same time each day.
    static let sameTimeDaily = RuleType(rawValue: "same_time_daily")
    /// Take with a full glass of water.
    static let withWater = RuleType(rawValue: "with_water")
    /// Must be given alongside another medication's dose.
    static let coAdminister = RuleType(rawValue: "co_administer")
    /// Explicitly unconstrained by food — free to move.
    static let foodOptional = RuleType(rawValue: "food_optional")

    /// Plain English, for a tired reader. Never clinical.
    var plainDescription: String {
        switch self {
        case .emptyStomach: "On an empty stomach"
        case .withFood: "With food"
        case .separation: "Kept apart from other tablets"
        case .avoidProtein: "Away from protein"
        case .sameTimeDaily: "Same time each day"
        case .withWater: "With a full glass of water"
        case .coAdminister: "Taken with another medicine's dose"
        case .foodOptional: "With or without food"
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}
