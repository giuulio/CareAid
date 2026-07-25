import Foundation

// Exercises the C2 models against a realistic `extract` response built from the
// CLAUDE.md §9 demo script. Run outside the app; the models only need Foundation.

nonisolated(unsafe) var failures = 0
func check(_ label: String, _ condition: Bool) {
    if condition {
        print("  ok   \(label)")
    } else {
        print("  FAIL \(label)")
        failures += 1
    }
}

let json = """
{
  "capture_id": "33333333-3333-4333-8333-333333333333",
  "events": [
    {
      "id": "44444444-4444-4444-8444-444444444444",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "medication",
      "occurred_at": "2026-07-24T20:00:00+00:00",
      "headline": "Evening co-careldopa dose missed",
      "detail": "Found still in the tray.",
      "severity": 2,
      "tags": ["adherence"],
      "confidence": 0.9
    },
    {
      "id": "44444444-4444-4444-8444-444444444445",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "care_task",
      "occurred_at": "2026-07-25T03:00:00.123456Z",
      "headline": "Up at three again",
      "severity": 1,
      "tags": [],
      "confidence": 0.8
    }
  ],
  "artifacts": [
    {
      "id": "55555555-5555-4555-8555-555555555551",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "task",
      "status": "proposed",
      "confidence": 0.95,
      "created_at": "2026-07-25T09:15:00Z",
      "payload": {
        "title": "Ring the surgery about Mum's evening dose",
        "due_at": "2026-07-27T09:00:00Z",
        "why": "Third missed evening dose this month"
      }
    },
    {
      "id": "55555555-5555-4555-8555-555555555552",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "family_update",
      "status": "proposed",
      "confidence": 0.9,
      "payload": {
        "to_circle_member_id": "66666666-6666-4666-8666-666666666666",
        "to_name": "Tom",
        "channel": "whatsapp",
        "draft_text": "Hi Tom. Mum had a broken night and missed her evening tablet, but she's brighter now. I'm ringing the surgery about it."
      }
    },
    {
      "id": "55555555-5555-4555-8555-555555555553",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "calendar_event",
      "status": "proposed",
      "payload": {
        "title": "Dr Okafor — neurology",
        "starts_at": "2026-08-14T10:00:00Z",
        "ends_at": "2026-08-14T10:45:00Z",
        "location": "Royal Infirmary",
        "notes": "Ask about night-time freezing",
        "reminders_min": [1440, 60]
      }
    },
    {
      "id": "55555555-5555-4555-8555-555555555554",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "question",
      "status": "proposed",
      "payload": {
        "question": "Is the night-time freezing related to the timing of her last dose?",
        "for_specialty": "neurology",
        "priority": 1
      }
    },
    {
      "id": "55555555-5555-4555-8555-555555555555",
      "recipient_id": "11111111-1111-4111-8111-111111111111",
      "capture_id": "33333333-3333-4333-8333-333333333333",
      "kind": "medication_update",
      "status": "proposed",
      "payload": {
        "medication_id": "77777777-7777-4777-8777-777777777777",
        "medication_name": "Co-careldopa",
        "field": "dose",
        "from": "100mg",
        "to": "125mg",
        "why": "Sarah said Dr Okafor increased it"
      }
    }
  ],
  "patterns": [
    { "observation": "Third missed evening dose this month",
      "evidence_event_ids": ["44444444-4444-4444-8444-444444444444"] }
  ],
  "flags": [
    { "type": "ambiguous_date", "text": "the 14th",
      "ask": "Is the neurology appointment 14 August?" },
    { "type": "something_we_have_not_seen_before", "ask": "Unknown flag type" }
  ],
  "brief": {
    "id": "88888888-8888-4888-8888-888888888888",
    "recipient_id": "11111111-1111-4111-8111-111111111111",
    "version": 7,
    "generated_at": "2026-07-25T09:15:00Z",
    "source_capture_id": "33333333-3333-4333-8333-333333333333",
    "content": {
      "one_liner": "Margaret is managing, but evening doses keep slipping.",
      "current_concerns": [
        { "text": "Night-time freezing", "since": "2026-07-02", "trend": "worsening" }
      ],
      "medications": [
        { "name": "Co-careldopa", "dose": "100mg", "schedule": "4x daily",
          "adherence_note": "Evening dose missed three times this month" }
      ],
      "recent_changes": ["Joy's evening visit moved to 18:00"],
      "open_questions": [],
      "whats_working": ["Morning routine is settled"]
    }
  }
}
"""

print("\nDecoding the §9 demo-script response:")
let response = try JSONCoding.decoder.decode(ExtractionResponse.self, from: Data(json.utf8))

check("all 2 events decoded", response.events.count == 2)
check("all 6 flags/artifacts present", response.artifacts.count == 5 && response.flags.count == 2)
var utc = Calendar(identifier: .gregorian)
utc.timeZone = TimeZone(identifier: "UTC")!
let expectedOccurredAt = utc.date(from: DateComponents(year: 2026, month: 7, day: 24, hour: 20))!
check("offset timestamp +00:00 parsed", response.events[0].occurredAt == expectedOccurredAt)
check("fractional-second timestamp parsed", response.events[1].occurredAt.timeIntervalSince1970 > 0)
check("severity 2 -> .medium", response.events[0].severity == .medium)
check("care_task snake_case -> .careTask", response.events[1].kind == .careTask)
check("event detail optional absent is nil", response.events[1].detail == nil)

print("\nArtifact payload dispatch:")
check("kind derives from payload", response.artifacts.map(\.kind) == [
    .task, .familyUpdate, .calendarEvent, .question, .medicationUpdate,
])

guard case .task(let task) = response.artifacts[0].payload else { fatalError("not a task") }
check("task.why", task.why == "Third missed evening dose this month")
check("task.due_at parsed", task.dueAt != nil)

guard case .familyUpdate(let update) = response.artifacts[1].payload else { fatalError("not an update") }
check("family_update resolved Tom", update.toName == "Tom" && update.channel == .whatsapp)

guard case .calendarEvent(let event) = response.artifacts[2].payload else { fatalError("not an event") }
check("calendar reminders_min", event.remindersMin == [1440, 60])

guard case .medicationUpdate(let med) = response.artifacts[4].payload else { fatalError("not a med update") }
check("medication_update field", med.field == .dose && med.to == "125mg")
check("medication_update why is attribution", med.why.contains("Dr Okafor"))

print("\nTransient extras and the brief:")
check("pattern evidence ids", response.patterns[0].evidenceEventIDs.count == 1)
check("known flag type", response.flags[0].type == .ambiguousDate)
check("UNKNOWN flag type survives decode", response.flags[1].type.rawValue == "something_we_have_not_seen_before")
check("brief one_liner", response.brief?.content.oneLiner.hasPrefix("Margaret") == true)
check("brief concern PlainDate", response.brief?.content.currentConcerns[0].since == PlainDate(year: 2026, month: 7, day: 2))
check("brief concern trend", response.brief?.content.currentConcerns[0].trend == .worsening)
check("brief empty array defaults", response.brief?.content.openQuestions.isEmpty == true)

print("\nRound trip (encode then decode):")
let reencoded = try JSONCoding.encoder.encode(response)
let again = try JSONCoding.decoder.decode(ExtractionResponse.self, from: reencoded)
let encodedText = String(decoding: reencoded, as: UTF8.self)
// Regression guard: .iso8601.time(...) builds a TIME-ONLY style, which encoded
// every timestamp as 1 Jan 1970 while the build stayed green.
check("encoder emits the date, not just the time",
      encodedText.contains("2026-07-24T20:00:00"))
check("encoder keeps fractional seconds", encodedText.contains("2026-07-24T20:00:00.000"))

check("whole-second event survives exactly", again.events[0] == response.events[0])
check("artifacts survive", again.artifacts == response.artifacts)
check("patterns survive", again.patterns == response.patterns)
check("flags survive", again.flags == response.flags)
check("brief survives", again.brief == response.brief)

// ISO8601 formatting caps at milliseconds; Postgres emits microseconds. The
// .123456 fixture above is therefore expected to land within 1ms, not exactly.
let microsecondDrift = abs(
    again.events[1].occurredAt.timeIntervalSince1970
        - response.events[1].occurredAt.timeIntervalSince1970
)
check("microsecond input round-trips within 1ms", microsecondDrift < 0.001)

print("\nRow models straight from Postgres:")
let medJSON = """
{ "id": "77777777-7777-4777-8777-777777777777",
  "recipient_id": "11111111-1111-4111-8111-111111111111",
  "name": "Co-careldopa", "dose": "100mg",
  "schedule": "4x daily: 8am, 12pm, 4pm, 8pm",
  "scheduled_times": ["08:00:00", "12:00:00", "16:00:00", "20:00:00"],
  "quantity_remaining": 42, "started_on": "2021-03-09", "active": true }
"""
let medication = try JSONCoding.decoder.decode(Medication.self, from: Data(medJSON.utf8))
check("time[] -> [TimeOfDay]", medication.scheduledTimes == [
    TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 16, minute: 0), TimeOfDay(hour: 20, minute: 0),
])
check("TimeOfDay sorts and does arithmetic",
      medication.scheduledTimes.max()?.minutesSinceMidnight == 1200)
check("date column -> PlainDate, no timezone shift",
      medication.startedOn?.description == "2021-03-09")

let caregiverJSON = """
{ "id": "22222222-2222-4222-8222-222222222222", "name": "Sarah", "relation": "daughter",
  "work_hours": { "blocks": [
    { "label": "Work", "days": ["mon","tue","wed","thu","fri"],
      "start": "09:00:00", "end": "17:30:00" },
    { "label": "Standup", "days": ["mon","tue","wed","thu","fri"],
      "start": "09:00:00", "end": "09:30:00" } ] } }
"""
let sarah = try JSONCoding.decoder.decode(Caregiver.self, from: Data(caregiverJSON.utf8))
check("work_hours blocks", sarah.workHours.blocks.count == 2)
check("work block weekdays", sarah.workHours.blocks[0].days == [.mon, .tue, .wed, .thu, .fri])

let emptyHours = try JSONCoding.decoder.decode(
    Caregiver.self,
    from: Data(#"{"id":"22222222-2222-4222-8222-222222222222","name":"Sarah","work_hours":{}}"#.utf8)
)
check("schema default work_hours {} tolerated", emptyHours.workHours.blocks.isEmpty)

print("\nRejecting what the database would reject:")
let badKind = #"{"id":"55555555-5555-4555-8555-555555555551","recipient_id":"11111111-1111-4111-8111-111111111111","kind":"send_an_email","status":"proposed","payload":{}}"#
do {
    _ = try JSONCoding.decoder.decode(Artifact.self, from: Data(badKind.utf8))
    check("invalid artifact kind rejected at decode", false)
} catch {
    check("invalid artifact kind rejected at decode", true)
}

let badSeverity = #"{"id":"44444444-4444-4444-8444-444444444444","recipient_id":"11111111-1111-4111-8111-111111111111","kind":"symptom","occurred_at":"2026-07-24T20:00:00Z","headline":"x","severity":9,"tags":[]}"#
do {
    _ = try JSONCoding.decoder.decode(TimelineEvent.self, from: Data(badSeverity.utf8))
    check("out-of-range severity rejected at decode", false)
} catch {
    check("out-of-range severity rejected at decode", true)
}

print(failures == 0 ? "\nAll checks passed.\n" : "\n\(failures) FAILED\n")
exit(failures == 0 ? 0 : 1)
