import Foundation

/// Arranges Margaret's medication around **Sarah's** day.
///
/// This is the inversion CLAUDE.md §1 is built on. Every other tool assumes the
/// patient lives alone with a private nurse; nobody schedules around the person
/// actually handing over the pills. So the caregiver's work, commute and real
/// diary are hard constraints here, exactly like the label rules are.
///
/// ## What it will and will not do
///
/// Moving a dose by a few minutes so somebody is there to hand it over is
/// logistics. Moving it by hours is a change to how a medicine is taken, and
/// CLAUDE.md §2 rule 1 does not let us recommend that — not even implicitly, not
/// even helpfully. So the solver may only nudge a dose within
/// `Tolerance.comfortable`. Anything that cannot be solved inside that window
/// becomes a **question for a pharmacist or GP**, and the schedule is left
/// exactly as prescribed.
///
/// The same applies to label rules: a separation conflict is never resolved by
/// moving a tablet. It is reported, quoted from the label, and asked about.
nonisolated struct MedicationScheduler {

    enum Tolerance {
        /// How far a dose may be nudged for purely practical reasons.
        static let comfortable = 30
        /// Doses this close together are one handover, not two trips.
        static let clustering = 30
    }

    private let rules: RuleStore

    init(rules: RuleStore = .shared) {
        self.rules = rules
    }

    // MARK: - Entry point

    /// - Parameters:
    ///   - caregiver: Sarah. Her `workHours` blocks are when she is *not* free.
    ///   - helpers: Joy and anyone else whose blocks are when they *are* present.
    ///   - busy: real diary blocks for `day`, from EventKit.
    func plan(
        medications: [Medication],
        on day: Date,
        caregiver: Caregiver?,
        helpers: [Caregiver],
        busy: [BusyBlock] = []
    ) -> ProposedSchedule {
        let weekday = Weekday(day)

        // Kept unmerged for display and merged only for solving. Merging first
        // would collapse "Commute 08:00–09:00", "Standup 09:00–09:30" and
        // "Work 09:00–17:30" into one range wearing whichever label happened to
        // sort first — which is how a screen ends up telling Sarah she commutes
        // for nine and a half hours.
        let caregiverBlocks = (caregiver?.workHours.blocks ?? [])
            .filter { $0.days.contains(weekday) }
            .map { MinuteRange($0) }
            + busy.map(MinuteRange.init)
        let helperBlocks = helpers
            .flatMap(\.workHours.blocks)
            .filter { $0.days.contains(weekday) }
            .map { MinuteRange($0) }

        let unavailable = merge(caregiverBlocks)
        let helperWindows = merge(helperBlocks)

        let doses = place(medications, unavailable: unavailable, helperWindows: helperWindows)
        return ProposedSchedule(
            day: day,
            slots: cluster(doses),
            conflicts: separationConflicts(among: doses) + coverageConflicts(among: doses),
            unavailable: caregiverBlocks.sorted { $0.start < $1.start },
            helperWindows: helperBlocks.sorted { $0.start < $1.start }
        )
    }

    // MARK: - Placing each dose

    private func place(
        _ medications: [Medication],
        unavailable: [MinuteRange],
        helperWindows: [MinuteRange]
    ) -> [PlannedDose] {
        var placed: [PlannedDose] = []

        for medication in medications {
            let medicationRules = rules.rules(for: medication)
            for time in medication.scheduledTimes {
                let prescribed = time.minutesSinceMidnight
                let cover = coverage(at: prescribed, unavailable: unavailable, helperWindows: helperWindows)

                // Already covered: leave it exactly where the prescription put
                // it. The best schedule change is the one we don't make.
                if cover != .nobody {
                    placed.append(PlannedDose(
                        medication: medication, rules: medicationRules,
                        prescribed: prescribed, proposed: prescribed, coverage: cover
                    ))
                    continue
                }

                // Nudge, but only inside the tolerance. `nil` means there is no
                // honest fix — which becomes a question, not a bigger move.
                let nudged = nearestCovered(
                    to: prescribed, unavailable: unavailable, helperWindows: helperWindows
                )
                placed.append(PlannedDose(
                    medication: medication, rules: medicationRules,
                    prescribed: prescribed,
                    proposed: nudged ?? prescribed,
                    coverage: nudged.map {
                        coverage(at: $0, unavailable: unavailable, helperWindows: helperWindows)
                    } ?? .nobody
                ))
            }
        }

        return tieCoAdministered(placed)
    }

    /// Entacapone's label says it goes with each levodopa dose. That is a hard
    /// tie: wherever its partner ended up, it follows, rather than being solved
    /// as if it were an independent tablet.
    private func tieCoAdministered(_ doses: [PlannedDose]) -> [PlannedDose] {
        var result = doses
        for (index, dose) in result.enumerated() {
            guard let rule = dose.rules.first(where: { $0.type == .coAdminister }) else { continue }
            let sentence = rule.sourceSentence.lowercased()
            // The partner is named in the label sentence. Match on the words of
            // other medications we actually hold rather than parsing prose.
            let partner = result.first { candidate in
                candidate.medication.id != dose.medication.id
                    && candidate.medication.nameTokens.contains { sentence.contains($0) }
                    && candidate.prescribed == dose.prescribed
            }
            guard let partner else { continue }
            result[index].proposed = partner.proposed
            result[index].coverage = partner.coverage
            result[index].tiedTo = partner.medication.name
        }
        return result
    }

    // MARK: - Who is actually there

    private func coverage(
        at minute: Int, unavailable: [MinuteRange], helperWindows: [MinuteRange]
    ) -> Coverage {
        if helperWindows.contains(where: { $0.contains(minute) }) { return .helper }
        if unavailable.contains(where: { $0.contains(minute) }) { return .nobody }
        return .caregiver
    }

    /// Closest covered minute within tolerance, preferring the smallest move.
    private func nearestCovered(
        to minute: Int, unavailable: [MinuteRange], helperWindows: [MinuteRange]
    ) -> Int? {
        for offset in 1 ... Tolerance.comfortable {
            for candidate in [minute - offset, minute + offset] where (0 ..< 1440).contains(candidate) {
                if coverage(at: candidate, unavailable: unavailable, helperWindows: helperWindows) != .nobody {
                    return candidate
                }
            }
        }
        return nil
    }

    // MARK: - Grouping into handovers

    /// One trip with four tablets beats four trips with one. Doses within
    /// `Tolerance.clustering` of each other become a single handover.
    private func cluster(_ doses: [PlannedDose]) -> [ScheduleSlot] {
        var slots: [ScheduleSlot] = []
        for dose in doses.sorted(by: { $0.proposed < $1.proposed }) {
            if let index = slots.firstIndex(where: {
                abs($0.minute - dose.proposed) <= Tolerance.clustering
            }) {
                slots[index].doses.append(dose)
            } else {
                slots.append(ScheduleSlot(minute: dose.proposed, doses: [dose]))
            }
        }
        return slots
    }

    // MARK: - Conflicts, which are always questions

    /// A label separation rule that the current times violate.
    ///
    /// Reported, never resolved. The output is a question for a pharmacist,
    /// quoting the label — CLAUDE.md §2 rule 1 and §12's "a conflict never
    /// changes a schedule".
    private func separationConflicts(among doses: [PlannedDose]) -> [ScheduleConflict] {
        var conflicts: [ScheduleConflict] = []
        var seen = Set<String>()

        for dose in doses {
            guard let rule = dose.rules.first(where: { $0.type == .separation }),
                  let hours = rule.hours else { continue }
            let required = Int(hours * 60)

            let tooClose = doses
                .filter { $0.medication.id != dose.medication.id }
                .filter { abs($0.proposed - dose.proposed) < required }
            guard !tooClose.isEmpty else { continue }

            // One question per medication that has the rule, not one per pair.
            //
            // The label says to separate it from "drugs known to interfere with
            // absorption" — it does not say which ones those are, and working
            // that out means reading Drug Interactions and deciding which
            // medicines interact. That is pharmacology, and §2 rule 1 puts it
            // firmly out of bounds. So we name everything sharing the time,
            // state what the label asks for, and let the pharmacist say which
            // of them actually matters.
            let key = dose.medication.name
            guard seen.insert(key).inserted else { continue }

            let others = Set(tooClose.map(\.medication.name)).sorted()
            let time = TimeOfDay(minutes: dose.proposed).display
            let simultaneous = tooClose.allSatisfy { $0.proposed == dose.proposed }

            conflicts.append(ScheduleConflict(
                medicationNames: [dose.medication.name] + others,
                headline: "\(dose.medication.name) is at the same time as \(Self.count(others.count))",
                detail: (simultaneous
                    ? "\(dose.medication.name) and \(Self.list(others)) are all set for \(time). "
                    : "\(dose.medication.name) is at \(time), close to \(Self.list(others)). ")
                    + "Its label asks for \(Self.hoursText(hours)) between it and anything "
                    + "that affects how it's absorbed.",
                citation: rule.sourceSentence,
                question: QuestionPayload(
                    question: "Mum takes her \(dose.medication.name) at \(time), "
                        + "at the same time as \(Self.list(others)). The label says to keep "
                        + "\(Self.hoursText(hours)) between it and anything that affects "
                        + "absorption — is her timing right?",
                    forSpecialty: "Pharmacy",
                    priority: 1
                )
            ))
        }
        return conflicts
    }

    private static func count(_ n: Int) -> String {
        n == 1 ? "another medicine" : "\(n) of her other medicines"
    }

    /// Doses nobody can be there for. The caregiver-first failure mode, and the
    /// one no other app looks for.
    private func coverageConflicts(among doses: [PlannedDose]) -> [ScheduleConflict] {
        let uncovered = doses.filter { $0.coverage == .nobody }
        guard !uncovered.isEmpty else { return [] }

        let byTime = Dictionary(grouping: uncovered, by: \.proposed)
        return byTime.keys.sorted().map { minute in
            let names = byTime[minute, default: []].map(\.medication.name).sorted()
            let time = TimeOfDay(minutes: minute).display
            return ScheduleConflict(
                medicationNames: names,
                headline: "Nobody's there for the \(time) dose",
                detail: "You're busy at \(time) and Joy isn't there either. "
                    + "\(Self.list(names)) \(names.count == 1 ? "is" : "are") due then.",
                citation: nil,
                question: QuestionPayload(
                    question: "Mum's \(Self.list(names)) \(names.count == 1 ? "is" : "are") due at "
                        + "\(time), when I'm at work and her carer isn't there. "
                        + "What are the options for covering that dose?",
                    forSpecialty: "GP",
                    priority: 1
                )
            )
        }
    }

    // MARK: - Words

    private static func hoursText(_ hours: Double) -> String {
        let whole = Int(hours)
        return hours == Double(whole)
            ? "\(whole) hour\(whole == 1 ? "" : "s")"
            : String(format: "%.1f hours", hours)
    }

    private static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default: names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }

    // MARK: - Ranges

    private func merge(_ ranges: [MinuteRange]) -> [MinuteRange] {
        let sorted = ranges.sorted { $0.start < $1.start }
        var merged: [MinuteRange] = []
        for range in sorted {
            if let last = merged.last, range.start <= last.end {
                merged[merged.count - 1] = MinuteRange(
                    start: last.start, end: max(last.end, range.end), label: last.label
                )
            } else {
                merged.append(range)
            }
        }
        return merged
    }
}
