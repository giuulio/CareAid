import SwiftUI

/// Her whole medication list, grouped by when it is taken.
///
/// The other half of the calendar: the calendar answers "what about this day?",
/// this answers "what is she on?" — the question every clinician opens with.
struct MedicationsView: View {
    @State private var model = MedicationsViewModel()

    var body: some View {
        List {
            switch model.state {
            case .loading:
                Text("Fetching her list…")
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)

            case .failed(let message):
                CalendarNotice(
                    title: "Can't show her medication",
                    detail: message,
                    retry: { Task { await model.load() } }
                )

            case .loaded:
                loaded
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.surface)
        .navigationTitle("Her medication")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
    }

    @ViewBuilder
    private var loaded: some View {
        if model.medications.isEmpty {
            Text("Nothing on her list yet.")
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
        } else {
            ForEach(model.groups) { group in
                Section(group.bucket.rawValue) {
                    ForEach(group.medications) { medication in
                        MedicationRow(
                            medication: medication,
                            rules: model.rules(for: medication)
                        )
                    }
                }
            }

            Section {
                Text(RuleStore.shared.disclaimer)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            } header: {
                Text("\(model.medications.count) medicines")
            }
        }
    }
}

/// One medicine: what it is, when it's taken, and anything the label says about
/// timing. Reference data, quoted — never advice (CLAUDE.md §2, rule 1).
struct MedicationRow: View {
    let medication: Medication
    let rules: [MedicationRule]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
                Text(medication.name)
                    .themeFont(Theme.TypeScale.bodyStrong)
                    .foregroundStyle(Theme.Palette.ink)
                Spacer(minLength: Theme.Space.s)
                if let dose = medication.dose {
                    Text(dose)
                        .themeFont(Theme.TypeScale.meta)
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
            }

            if let schedule = medication.schedule {
                Text(schedule)
                    .themeFont(Theme.TypeScale.body)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }

            if !times.isEmpty {
                Label(times, systemImage: "clock")
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.accent)
                    .monospacedDigit()
            }

            ForEach(rules, id: \.self) { rule in
                Label(rule.type.plainDescription, systemImage: "info.circle")
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }

            if let remaining = medication.quantityRemaining {
                Text(remaining <= 14 ? "\(remaining) left — worth a repeat" : "\(remaining) left")
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .padding(.vertical, Theme.Space.xs)
    }

    private var times: String {
        medication.scheduledTimes.map(\.display).joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { MedicationsView() }
}
