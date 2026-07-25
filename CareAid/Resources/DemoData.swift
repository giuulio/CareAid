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
    forgotten her evening Sinemet, I found it still in the tray. She seemed
    a bit confused this morning but she's better now. I said I'd ring the
    surgery about the dose because this is the third time this month.
    Oh, and Tom's asking how she is. Her neurology thing is the 14th isn't it —
    I need to remember to ask them about the night-time freezing.
    """

    /// Words distinctive enough that three of them together mean the demo
    /// script and not a real note about a real evening.
    private static let markers = [
        "sinemet", "tray", "tom", "surgery", "freezing", "neurology", "three again",
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
        var components = DateComponents(year: year, month: 8, day: 14, hour: 9, minute: 0)
        components.timeZone = Config.displayTimeZone

        guard let date = calendar.date(from: components) else { return .now }
        if date > .now { return date }
        components.year = year + 1
        return calendar.date(from: components) ?? date
    }

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
                )
            ],
            artifacts: [
                Artifact(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    payload: .task(
                        TaskPayload(
                            title: "Ring the surgery about Mum's evening dose",
                            dueAt: Calendar.current.date(
                                byAdding: .day,
                                value: 3,
                                to: Date()
                            ),
                            why: "Sarah said this is the third missed evening dose this month."
                        )
                    ),
                    status: .proposed,
                    confidence: 0.95
                ),

                Artifact(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    payload: .familyUpdate(
                        FamilyUpdatePayload(
                            toCircleMemberID: nil,
                            toName: "Tom",
                            channel: .whatsapp,
                            draftText: "Mum had a difficult night but she's doing better this morning. I found her evening medication still in the tray and I'm going to speak with the surgery."
                        )
                    ),
                    status: .proposed,
                    confidence: 0.9
                ),

                Artifact(
                    id: UUID(),
                    recipientID: recipientID,
                    captureID: captureID,
                    payload: .question(
                        QuestionPayload(
                            question: "Could we discuss Mum's night-time freezing?",
                            forSpecialty: "Neurology",
                            priority: 1
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
                            title: "Neurology appointment with Dr Okafor",
                            startsAt: neurologyAppointment,
                            endsAt: nil,
                            location: nil,
                            notes: "Questions about night-time freezing.",
                            remindersMin: [1440, 60]
                        )
                    ),
                    status: .proposed,
                    confidence: 0.85
                )
            ],
            patterns: [
                Pattern(
                    observation: "Third missed evening dose this month.",
                    evidenceEventIDs: []
                )
            ],
            flags: [
                Flag(
                    type: .ambiguousDate,
                    text: "the 14th",
                    ask: "Is the neurology appointment 14 August?"
                )
            ],
            brief: Brief(
                id: UUID(),
                recipientID: recipientID,
                version: 1,
                content: BriefContent(
                    oneLiner: "Margaret Ellis lives with Parkinson's and Sarah helps coordinate daily care.",
                    currentConcerns: [],
                    medications: [],
                    recentChanges: [],
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
