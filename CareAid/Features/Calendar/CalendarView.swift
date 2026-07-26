import SwiftUI

/// One screen for everything time-shaped: what happened, what's coming, and
/// when her tablets are due.
///
/// Deliberately built from stock iOS parts — a month grid and a grouped list —
/// because a calendar is the one thing every phone owner already knows how to
/// read. Type still comes from `Theme` so it stays at CareAid's sizes.
struct CalendarView: View {
    @State private var model = CalendarViewModel()

    var body: some View {
        List {
            monthGrid
            appointment
            record
            tablets
            howShesDoing
        }
        .listStyle(.insetGrouped)
        // Native structure, CareAid's paper. The default grouped background is
        // cool grey and would be the one screen in the app that isn't warm.
        // The toolbar needs telling too, or rows scroll up into a clear bar and
        // collide with the title.
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.surface)
        .toolbarBackground(Theme.Palette.surface, for: .navigationBar)
        .navigationTitle(DisplayDate.dayLabel(for: model.selectedDay))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !model.isToday {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") { model.selectedDay = .now }
                }
            }
        }
        .task { await model.load() }
        .onChange(of: model.selectedDay) { Task { await model.reschedule() } }
    }

    // MARK: - The month

    private var monthGrid: some View {
        Section {
            DatePicker(
                "Day",
                selection: $model.selectedDay,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()

            if case .failed(let message) = model.state {
                CalendarNotice(
                    title: "Can't reach her records",
                    detail: message,
                    retry: { Task { await model.load() } }
                )
            }
        }
    }

    // MARK: - Appointments

    @ViewBuilder
    private var appointment: some View {
        if !model.dayAppointments.isEmpty {
            Section("Appointment") {
                ForEach(model.dayAppointments) { event in
                    CalendarEventRow(event: event)
                }
                ForEach(Array(model.questionTexts.enumerated()), id: \.offset) { _, question in
                    Label(question, systemImage: "questionmark.circle")
                        .themeFont(Theme.TypeScale.body)
                }
                PackRow(
                    url: model.packURL,
                    building: model.buildingPack,
                    make: { Task { await model.makePack() } }
                )
            }
        } else if model.isToday, let next = model.nextAppointment {
            Section("Coming up") {
                Button {
                    model.selectedDay = next.occurredAt
                } label: {
                    CalendarEventRow(event: next, showsDay: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - What was recorded

    @ViewBuilder
    private var record: some View {
        Section("What happened") {
            if model.dayRecord.isEmpty {
                Text(model.isToday
                     ? "Nothing recorded yet today. Tap the mic and say what happened."
                     : "Nothing recorded on this day.")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            } else {
                ForEach(model.dayRecord) { event in
                    CalendarEventRow(event: event)
                }
            }
        }
    }

    // MARK: - Medication

    @ViewBuilder
    private var tablets: some View {
        if let schedule = model.schedule {
            Section {
                ForEach(schedule.slots) { slot in
                    DoseRow(slot: slot)
                }
                if model.canOfferCalendar {
                    Button {
                        Task { await model.allowCalendar() }
                    } label: {
                        Label("Work around my diary", systemImage: "calendar.badge.plus")
                            .themeFont(Theme.TypeScale.bodyStrong)
                            .frame(minHeight: Theme.Size.minTouchTarget, alignment: .leading)
                    }
                }
            } header: {
                Text("Her tablets")
            } footer: {
                YourDayFootnote(schedule: schedule, usedCalendar: model.usedCalendar)
            }

            // Conflicts get their own section: they are the only thing on this
            // screen that wants a decision.
            if !schedule.conflicts.isEmpty {
                Section("Worth asking about") {
                    ForEach(schedule.conflicts) { conflict in
                        ConflictRow(conflict: conflict, state: model.askState(for: conflict)) {
                            Task { await model.ask(conflict) }
                        }
                    }
                }
            }
        }
    }

    // MARK: - The brief

    @ViewBuilder
    private var howShesDoing: some View {
        if let brief = model.brief {
            Section("How she's doing") {
                BriefSummary(brief: brief)
            }
        }
    }
}

#Preview {
    NavigationStack { CalendarView() }
}
