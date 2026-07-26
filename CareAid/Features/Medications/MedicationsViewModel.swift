import Foundation
import Observation

/// Everything Margaret takes, in one list.
///
/// Read-only on purpose: the only two things allowed to change a medication row
/// are an approved `medication_update` (C8) and the schedule screen's manual
/// override (§10). A list is not either of them.
@Observable
final class MedicationsViewModel {

    enum State {
        case loading
        case loaded
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var medications: [Medication] = []

    func load() async {
        state = .loading
        do {
            medications = try await MedicationRepository().active()
            state = .loaded
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// The label rules behind a medication, for the "why is it at this time"
    /// line. Reference data read off a DailyMed label — never advice.
    func rules(for medication: Medication) -> [MedicationRule] {
        RuleStore.shared.rules(for: medication)
    }

    /// Grouped by when she takes them, because that is how a caregiver holds
    /// twelve boxes in her head: the morning ones, the evening ones.
    var groups: [Group] {
        let buckets = Dictionary(grouping: medications) { medication in
            Bucket(medication.scheduledTimes)
        }
        return Bucket.allCases.compactMap { bucket in
            guard let items = buckets[bucket], !items.isEmpty else { return nil }
            return Group(bucket: bucket, medications: items.sorted { $0.name < $1.name })
        }
    }

    struct Group: Identifiable {
        let bucket: Bucket
        let medications: [Medication]
        var id: Bucket { bucket }
    }

    /// A rough time of day, only ever used to sort the list into sections.
    enum Bucket: String, CaseIterable, Hashable {
        case morning = "Mornings"
        case daytime = "Through the day"
        case evening = "Evenings"
        case unscheduled = "No set time"

        init(_ times: [TimeOfDay]) {
            guard let first = times.min() else { self = .unscheduled; return }
            if times.count > 2 {
                self = .daytime
            } else if first.hour < 12 {
                self = .morning
            } else {
                self = .evening
            }
        }
    }
}
