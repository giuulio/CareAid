import SwiftUI

/// One handover: a time, who's there for it, and everything due then.
struct ScheduleSlotRow: View {
    let slot: ScheduleSlot

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Space.m) {
                    Text(slot.time.display)
                        .themeFont(Theme.TypeScale.cardHeadline)
                        .foregroundStyle(Theme.Palette.ink)
                    Spacer(minLength: Theme.Space.s)
                    coverageBadge
                }

                ForEach(slot.doses) { dose in
                    doseRow(dose)
                }
            }
        }
    }

    private var coverageBadge: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: slot.coverage.symbol)
            Text(slot.coverage.plainDescription)
        }
        .themeFont(Theme.TypeScale.meta)
        .foregroundStyle(
            slot.coverage == .nobody ? Theme.Palette.ink : Theme.Palette.inkSecondary
        )
        .padding(.horizontal, Theme.Space.m)
        .padding(.vertical, Theme.Space.xs)
        .background(
            slot.coverage == .nobody ? Theme.Palette.accentSoft : Theme.Palette.surface
        )
        .clipShape(.rect(cornerRadius: Theme.Radius.pill, style: .continuous))
    }

    private func doseRow(_ dose: PlannedDose) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(dose.medication.name)
                .themeFont(Theme.TypeScale.body)
                .foregroundStyle(Theme.Palette.ink)

            if let note = note(for: dose) {
                Text(note)
                    .themeFont(Theme.TypeScale.meta)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Dose, why it moved, and why it is tied to something else — in that
    /// order of importance, one line, never all three at once.
    private func note(for dose: PlannedDose) -> String? {
        var parts: [String] = []
        if let dose = dose.medication.dose { parts.append(dose) }
        if dose.moved {
            parts.append("moved from \(dose.prescribedTime.display)")
        }
        if let tied = dose.tiedTo {
            parts.append("goes with \(tied)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
