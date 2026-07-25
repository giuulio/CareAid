import Foundation

/// Static demo content used for the hackathon recording.
/// 
/// This mirrors the expected extraction output without depending on:
/// - Supabase
/// - Edge Functions
/// - LLM availability
///
/// Production flow replaces this with ExtractionService output.
enum DemoData {

    static let transcript = """
    Right, so — Mum had a bad night, she was up at three again and she'd
    forgotten her evening Sinemet, I found it still in the tray. She seemed
    a bit confused this morning but she's better now. I said I'd ring the
    surgery about the dose because this is the third time this month.
    Oh, and Tom's asking how she is. Her neurology thing is the 14th isn't it —
    I need to remember to ask them about the night-time freezing.
    """

    static let extractionResponse: ExtractionResponse = {

        let captureID = UUID()
        let recipientID = UUID()

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
                            startsAt: Calendar.current.date(
                                bySetting: .day,
                                value: 14,
                                of: Date()
                            ) ?? Date(),
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
