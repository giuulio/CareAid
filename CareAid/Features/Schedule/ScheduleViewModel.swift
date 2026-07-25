import Foundation
import Observation

/// Drives the Schedule screen: what Mum takes, when, and who is actually there
/// to hand it over.
@Observable
final class ScheduleViewModel {

    enum State {
        case loading
        case loaded
        case failed(String)
    }

    /// Whether a conflict has been turned into a question yet.
    enum AskState: Equatable {
        case pending
        case working
        case asked
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var schedule: ProposedSchedule?
    private(set) var medications: [Medication] = []
    private(set) var asked: [String: AskState] = [:]

    /// True once we've read her diary. When false the screen says the proposal
    /// is based on her working hours alone, rather than quietly implying we
    /// looked at her calendar and found it empty.
    private(set) var usedCalendar = false

    /// The day being scheduled.
    ///
    /// Overridable in DEBUG because Sarah works Monday to Friday, so on a
    /// weekend the caregiver constraints correctly vanish and the screen has
    /// nothing to demonstrate. `-scheduleDay 2026-07-27` pins it to a weekday
    /// for checking the interesting path — and is worth knowing about if the
    /// demo slot lands on a Saturday.
    let day: Date = {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "scheduleDay") {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = Config.displayTimeZone
            formatter.dateFormat = "yyyy-MM-dd"
            if let pinned = formatter.date(from: raw) { return pinned }
        }
        #endif
        return .now
    }()

    func load() async {
        state = .loading
        do {
            let medicationRepository = try MedicationRepository()
            let caregivers = try CaregiverRepository()

            async let medicationsTask = medicationRepository.active()
            async let currentTask = caregivers.currentUser()
            async let allTask = caregivers.all()

            let (meds, sarah, everyone) = try await (medicationsTask, currentTask, allTask)
            medications = meds

            // Her real diary is a hard constraint, but a declined permission
            // must not empty the screen — fall back to her working hours.
            let busy = await busyBlocks()

            schedule = MedicationScheduler().plan(
                medications: meds,
                on: day,
                caregiver: sarah,
                helpers: everyone.filter { $0.id != sarah?.id },
                busy: busy
            )
            state = .loaded
            logPlan()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// The plan in one console block.
    ///
    /// The interesting part of this screen is below the fold and nothing can
    /// scroll the simulator from a script, so this is how the solver gets
    /// checked without a human and a mouse.
    private func logPlan() {
        #if DEBUG
        guard let schedule else { return }
        print("[CareAid] schedule for \(DisplayDate.dayLabel(for: day))")
        for block in schedule.unavailable {
            print("  busy   \(block.displayRange)  \(block.label ?? "")")
        }
        for block in schedule.helperWindows {
            print("  carer  \(block.displayRange)  \(block.label ?? "")")
        }
        for slot in schedule.slots {
            print("  \(slot.time.display)  \(slot.coverage.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0))"
                  + slot.doses.map(\.medication.name).joined(separator: ", "))
        }
        print("  \(schedule.conflicts.count) conflict(s)")
        for conflict in schedule.conflicts {
            print("  conflict: \(conflict.headline) [\(conflict.medicationNames.joined(separator: ","))]")
        }
        #endif
    }

    /// Turns one conflict into a question she can take to the appointment.
    ///
    /// The only thing a conflict is ever allowed to produce. It never changes
    /// a time (CLAUDE.md §2 rule 1).
    func ask(_ conflict: ScheduleConflict) async {
        asked[conflict.id] = .working
        do {
            try await ArtifactRepository().propose(question: conflict.question)
            asked[conflict.id] = .asked
        } catch {
            asked[conflict.id] = .failed(error.localizedDescription)
        }
    }

    func askState(for conflict: ScheduleConflict) -> AskState {
        asked[conflict.id] ?? .pending
    }

    private func busyBlocks() async -> [BusyBlock] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        do {
            let blocks = try await CalendarService().busyBlocks(from: start, to: end)
            usedCalendar = true
            return blocks.map {
                BusyBlock(title: nil, start: $0.start, end: $0.end, on: day)
            }
        } catch {
            usedCalendar = false
            return []
        }
    }
}
