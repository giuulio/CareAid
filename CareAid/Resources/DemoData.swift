import Foundation

/// The §9 demo capture, and what a good extraction of it looks like.
///
/// Insurance, not a feature. Conference wifi kills more demos than bugs do, so
/// if `extract` cannot be reached and the caregiver has just said the demo
/// script, the Review sheet fills from here rather than showing a failure.
///
/// Two things keep this honest:
///
///  * It only fires for the demo script — `resembles(_:)` is deliberately
///    narrow, so an ordinary capture that fails still fails visibly.
///  * Every fallback is logged loudly, and the artifacts carry ids that exist
///    in no database, so `ReviewViewModel` knows not to PATCH them.
nonisolated enum DemoData {

    static let transcript = """
    Right, so — Mum had a bad night, she was up at three again and she'd
    forgotten her evening Sinemet, I found it still in the tray. She was a bit
    confused this morning but she's better now. Dr Okafor's put her Sinemet up
    to 25/125 from today. Oh, and Tom's asking how she is. And her neurology
    appointment is the 14th of August, isn't it.
    """

    /// Words distinctive enough that three of them together mean the demo
    /// script and not a real note about a real evening.
    private static let markers = [
        "sinemet", "tray", "tom", "okafor", "neurology", "three again", "25/125",
    ]

    /// Whether this transcript is the demo script.
    ///
    /// Narrow on purpose. A genuine capture that fails extraction must surface
    /// the failure — a fallback that quietly masks one is worse than none,
    /// because it hides the bug until the morning of the demo.
    static func resembles(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return markers.count(where: lowered.contains) >= 3
    }

    /// Dr Okafor's appointment. CLAUDE.md pins it to 14 August; this resolves
    /// that to the next one that hasn't happened yet rather than to whatever
    /// `bySetting:` makes of the current month.
    static var neurologyAppointment: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Config.displayTimeZone
        let year = calendar.component(.year, from: .now)
        var components = DateComponents(year: year, month: 8, day: 14, hour: 10, minute: 0)
        components.timeZone = Config.displayTimeZone

        guard let date = calendar.date(from: components) else { return .now }
        if date > .now { return date }
        components.year = year + 1
        return calendar.date(from: components) ?? date
    }

    /// The circle's numbers, for when the backend that normally holds them is
    /// the thing that's missing. Synthetic, like everything else here.
    static func handle(for name: String) -> String? {
        switch name.lowercased() {
        case "tom": "+447700900123"
        case "joy": "+447700900456"
        default: nil
        }
    }

    /// Sinemet's row in `002_seed.sql`. The medication card writes to it, so a
    /// real id matters even in the fallback — a made-up one would update nothing
    /// the moment the backend came back.
    private static let sinemetID = UUID(uuidString: "44444444-4444-4444-8444-000000000001")!

    static let extractionResponse: ExtractionResponse = {

        // Not random: the offline response has to name the real recipient, and
        // a stable capture id keeps a retry from looking like a second note.
        let captureID = UUID(uuidString: "00000000-0000-4000-8000-00000000dem0")
            ?? UUID()
        let recipientID = Config.recipientID

        return ExtractionResponse(
            captureID: captureID,
            events: [
                TimelineEvent(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    kind: .medication,
                    occurredAt: Date(),
                    headline: "Evening Sinemet dose missed",
                    detail: "Found still in the tray.",
                    severity: .medium,
                    tags: ["adherence"],
                    confidence: 0.9
                ),
                TimelineEvent(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    kind: .symptom,
                    occurredAt: Date(),
                    headline: "Awake at three again, muddled this morning",
                    detail: "Better by the time Sarah recorded this.",
                    severity: .low,
                    tags: ["sleep", "confusion"],
                    confidence: 0.85
                )
            ],
            // Three, in the order she said them: her medicine, her brother,
            // her diary.
            artifacts: [
                Artifact(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    payload: .medicationUpdate(
                        MedicationUpdatePayload(
                            medicationID: sinemetID,
                            medicationName: "Co-careldopa (Sinemet)",
                            field: .dose,
                            from: "25/100mg",
                            to: "25/125mg",
                            why: "Sarah said Dr Okafor increased it."
                        )
                    ),
                    status: .proposed,
                    confidence: 0.92
                ),

                Artifact(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    payload: .familyUpdate(
                        FamilyUpdatePayload(
                            toCircleMemberID: UUID(uuidString: "33333333-3333-4333-8333-000000000001"),
                            toName: "Tom",
                            channel: .whatsapp,
                            draftText: "Mum had a broken night and missed her evening Sinemet, but she's brighter now. Dr Okafor has put her dose up to 25/125 from today. I'll let you know how she gets on."
                        )
                    ),
                    status: .proposed,
                    confidence: 0.9
                ),

                Artifact(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    payload: .calendarEvent(
                        CalendarEventPayload(
                            title: "Dr Okafor, neurology",
                            startsAt: neurologyAppointment,
                            endsAt: nil,
                            location: "Royal Infirmary, outpatients",
                            notes: "Ask about the night-time freezing.",
                            remindersMin: [1440, 60]
                        )
                    ),
                    status: .proposed,
                    confidence: 0.88
                )
            ],
            patterns: [
                Pattern(
                    observation: "Third missed evening dose this month.",
                    evidenceEventIDs: []
                )
            ],
            flags: [],
            brief: Brief(
                id: UUID(),
                recipientID: recipientID,
                version: 1,
                content: BriefContent(
                    oneLiner: "Margaret is managing at home, but her nights are getting harder.",
                    currentConcerns: [],
                    medications: [],
                    recentChanges: [
                        "Dr Okafor increased her Sinemet to 25/125"
                    ],
                    openQuestions: [
                        "Discuss night-time freezing with neurology."
                    ],
                    whatsWorking: [
                        "Sarah is keeping track of changes."
                    ]
                ),
                generatedAt: Date(),
                sourceCaptureID: captureID
            )
        )
    }()
}
