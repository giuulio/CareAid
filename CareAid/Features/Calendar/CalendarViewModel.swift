import Foundation
import Observation

/// Everything time-shaped about Margaret, keyed on one selected day.
///
/// Timeline, Schedule and Appointments used to be three destinations. They were
/// three answers to the same question — *what about this day?* — so they are one
/// screen now, and the month grid is the way into it.
@Observable
final class CalendarViewModel {

    enum State {
        case loading
        case loaded
        case failed(String)
    }

    /// Whether a medication timing conflict has been turned into a question yet.
    enum AskState: Equatable {
        case pending
        case working
        case asked
        case failed(String)
    }

    private(set) var state: State = .loading

    /// The day the whole screen is about.
    var selectedDay: Date = .now

    private(set) var recipient: Recipient?
    private(set) var brief: Brief?
    private(set) var events: [TimelineEvent] = []
    private(set) var medications: [Medication] = []
    private(set) var questions: [Artifact] = []

    private(set) var schedule: ProposedSchedule?
    /// True once we've read her real diary. When false the screen says the plan
    /// is built from her working hours alone, rather than quietly implying we
    /// looked and found nothing.
    private(set) var usedCalendar = false
    private(set) var asked: [String: AskState] = [:]

    private(set) var packURL: URL?
    private(set) var buildingPack = false

    private var caregiver: Caregiver?
    private var helpers: [Caregiver] = []

    // MARK: - Loading

    func load() async {
        state = .loading
        do {
            async let recipientTask = try RecipientRepository().current()
            async let briefTask = try BriefRepository().current()
            async let recentTask = try TimelineRepository().recent(limit: 300)
            async let upcomingTask = try TimelineRepository().upcoming(limit: 20)
            async let medicationsTask = try MedicationRepository().active()
            async let questionsTask = try ArtifactRepository().questions()
            async let caregiverTask = try CaregiverRepository().currentUser()
            async let everyoneTask = try CaregiverRepository().all()

            recipient = try await recipientTask
            brief = try await briefTask
            events = try await recentTask + upcomingTask
            medications = try await medicationsTask
            questions = try await questionsTask
            caregiver = try await caregiverTask
            helpers = try await everyoneTask.filter { $0.id != caregiver?.id }

            state = .loaded
            await reschedule()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Re-plans the medication day. Called on load and whenever she picks a new
    /// date — her diary and her working hours are different on a Saturday.
    func reschedule() async {
        guard !medications.isEmpty else { return }
        let busy = await busyBlocks()
        schedule = MedicationScheduler().plan(
            medications: medications,
            on: selectedDay,
            caregiver: caregiver,
            helpers: helpers,
            busy: busy
        )
    }

    private func busyBlocks() async -> [BusyBlock] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let start = calendar.startOfDay(for: selectedDay)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        do {
            let blocks = try await CalendarService().busyBlocks(from: start, to: end)
            usedCalendar = true
            return blocks.map { BusyBlock(title: nil, start: $0.start, end: $0.end, on: selectedDay) }
        } catch {
            usedCalendar = false
            return []
        }
    }

    // MARK: - The selected day

    var dayEvents: [TimelineEvent] {
        events
            .filter { DisplayDate.startOfDay(for: $0.occurredAt) == startOfSelectedDay }
            .sorted { $0.occurredAt < $1.occurredAt }
    }

    var dayAppointments: [TimelineEvent] {
        dayEvents.filter { $0.kind == .appointment }
    }

    /// Everything except the appointments, which get their own section.
    var dayRecord: [TimelineEvent] {
        dayEvents.filter { $0.kind != .appointment }
    }

    var nextAppointment: TimelineEvent? {
        events
            .filter { $0.kind == .appointment && $0.occurredAt >= .now }
            .min { $0.occurredAt < $1.occurredAt }
    }

    /// Days carrying something recorded, so the month grid can mark them.
    var daysWithEvents: Set<Date> {
        Set(events.map { DisplayDate.startOfDay(for: $0.occurredAt) })
    }

    private var startOfSelectedDay: Date {
        DisplayDate.startOfDay(for: selectedDay)
    }

    var isToday: Bool {
        startOfSelectedDay == DisplayDate.startOfDay(for: .now)
    }

    // MARK: - Actions

    /// Turns one timing conflict into a question she can take to the appointment.
    ///
    /// The only thing a conflict is ever allowed to produce. It never changes a
    /// time (CLAUDE.md §2, rule 1).
    func ask(_ conflict: ScheduleConflict) async {
        asked[conflict.id] = .working
        do {
            let artifact = try await ArtifactRepository().propose(question: conflict.question)
            questions.insert(artifact, at: 0)
            asked[conflict.id] = .asked
        } catch {
            asked[conflict.id] = .failed(error.localizedDescription)
        }
    }

    func askState(for conflict: ScheduleConflict) -> AskState {
        asked[conflict.id] ?? .pending
    }

    var questionTexts: [String] {
        questions.compactMap { artifact in
            if case .question(let payload) = artifact.payload { payload.question } else { nil }
        }
    }

    func makePack() async {
        buildingPack = true
        defer { buildingPack = false }

        // The pack is for the appointment, so only the recent run-up is
        // relevant — 90 days of history would bury it.
        let cutoff = Date.now.addingTimeInterval(-30 * 86_400)
        let recent = events.filter {
            $0.occurredAt >= cutoff && $0.occurredAt <= .now && $0.severity != .none
        }

        do {
            let document = PackDocument(
                recipient: recipient,
                brief: brief,
                questions: questionTexts,
                medications: medications,
                events: recent
            )
            packURL = try PDFService().render(document, named: "CareAid-appointment-pack")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
