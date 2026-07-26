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

    /// Whether an appointment has been put into her phone's own calendar yet.
    enum AddState: Equatable {
        case idle
        case working
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

    /// Appointments she has already approved into her diary. Read back because
    /// nothing copies an approved `calendar_event` into `timeline_event` — see
    /// `ArtifactRepository.diaryEntries()`.
    private(set) var diary: [Artifact] = []

    /// What is in the phone's Calendar app on the selected day. Empty when we
    /// have no access to look, which reads as "not in her calendar" and offers
    /// to put it there — the tap that follows asks for access.
    private(set) var phoneTitles: [String] = []
    private(set) var adding: [UUID: AddState] = [:]

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
            async let diaryTask = try ArtifactRepository().diaryEntries()
            async let caregiverTask = try CaregiverRepository().currentUser()
            async let everyoneTask = try CaregiverRepository().all()

            recipient = try await recipientTask
            brief = try await briefTask
            events = try await recentTask + upcomingTask
            medications = try await medicationsTask
            questions = try await questionsTask
            diary = try await diaryTask
            caregiver = try await caregiverTask
            helpers = try await everyoneTask.filter { $0.id != caregiver?.id }

            state = .loaded
            await reschedule()
            await refreshPhoneDiary()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Everything that depends on which day she is looking at: her tablets get
    /// re-planned around that day's diary, and that day's appointments get
    /// checked against her phone's calendar.
    func dayChanged() async {
        await reschedule()
        await refreshPhoneDiary()
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

    /// Shown as a row rather than an alert on arrival: the prompt is hers to
    /// ask for. Hidden once she has answered either way.
    var canOfferCalendar: Bool { CalendarService.canAsk }

    func allowCalendar() async {
        try? await CalendarService().requestAccess()
        await dayChanged()
    }

    private func busyBlocks() async -> [BusyBlock] {
        let (start, end) = CalendarService.dayWindow(selectedDay)

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

    /// The day's appointments as one list, each marked with whether it has
    /// actually reached the phone's Calendar app.
    var dayDiary: [DiaryItem] {
        DiaryItem.merged(appointments: dayAppointments, diary: diaryOnSelectedDay)
            .map { item in
                var item = item
                item.inPhoneCalendar = CalendarService.diaryContains(item.title, in: phoneTitles)
                return item
            }
    }

    private var diaryOnSelectedDay: [Artifact] {
        diary.filter { artifact in
            guard case .calendarEvent(let payload) = artifact.payload else { return false }
            return DisplayDate.startOfDay(for: payload.startsAt) == startOfSelectedDay
        }
    }

    func addState(for item: DiaryItem) -> AddState {
        adding[item.id] ?? .idle
    }

    /// Everything except the appointments, which get their own section.
    var dayRecord: [TimelineEvent] {
        dayEvents.filter { $0.kind != .appointment }
    }

    /// The next thing coming, from either record. Shown on today only, as a way
    /// into the day it's on — so it carries no diary status: that day hasn't
    /// been checked against her phone yet.
    var nextAppointment: DiaryItem? {
        DiaryItem
            .merged(
                appointments: events.filter { $0.kind == .appointment },
                diary: diary
            )
            .first { $0.startsAt >= .now }
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

    /// Puts an appointment CareAid knows about into her phone's own calendar.
    ///
    /// The other half of the Review card's yes: an appointment recorded before
    /// this screen existed — or seeded, or approved on a phone she has since
    /// wiped — is CareAid's alone until someone offers to write it out. Safe to
    /// tap twice: `CalendarService` finds the entry already there and edits it
    /// in place rather than writing a second one.
    func addToPhoneCalendar(_ item: DiaryItem) async {
        adding[item.id] = .working
        do {
            try await CalendarService().add(item.payload, keyedOn: item.id)
            await refreshPhoneDiary()
            adding[item.id] = .idle
        } catch {
            adding[item.id] = .failed(error.localizedDescription)
        }
    }

    /// Hands her over to the Calendar app on that day, where the rest of her
    /// life already is.
    func openInPhoneCalendar(_ item: DiaryItem) async {
        await CalendarService.openSystemCalendar(on: item.startsAt)
    }

    private func refreshPhoneDiary() async {
        phoneTitles = (try? await CalendarService().titles(on: selectedDay)) ?? []
    }

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
