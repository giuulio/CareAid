# CareAid — Project Brief

**Read this fully before writing code. This file is the source of truth.**

Hackathon build. iOS app. ~12 hours to submission. Optimise for a working demo on a physical iPhone, not for production quality.

---

## 1. What we're building

**CareAid** — a caregiver-first app. One line: *Say it once. We do the rest.*

A caregiver speaks one messy, tired thought. One AI pass turns it into a timeline entry, a calendar event, a drafted WhatsApp message to a sibling, a task, and a question for the next doctor's appointment. One input, five destinations, four taps.

**The inversion:** every other tool makes you pick the destination first — open Calendar to add an event, open WhatsApp to message your brother, open Notes to remember what to ask the consultant. The mental load isn't typing. It's routing. We take the routing.

**The differentiator:** CareAid schedules medication around **the caregiver's** real life — their work meetings, their commute — not just the patient's. Every med app assumes the patient lives alone with a private nurse. Nobody schedules around the person actually handing over the pills.

### Personas (use these exact names everywhere, incl. seed data)

- **Margaret Ellis**, 78. Parkinson's (dx 2021), atrial fibrillation. Lives alone.
- **Sarah**, 52, her daughter. Primary caregiver. Full-time job. **The app user.**
- **Tom**, Sarah's brother, in Manchester. Gets updates.
- **Dr Okafor**, neurology. Appointment 14 August.
- **Joy**, paid carer, visits 07:30 and 18:00 daily.

---

## 2. Non-negotiable rules

1. **Never medical advice.** CareAid never diagnoses, never suggests a cause, never recommends a treatment or a dose. It records what the human said and routes it. Where a medication timing conflict is detected, the output is always *a question for a pharmacist or GP* — never an instruction. Recording a medication change the caregiver **reports** is not advice — but it must be attributed to whoever made the decision, and never inferred by us.
2. **All data is synthetic.** No real patient data anywhere, ever. Hackathon rule.
3. **Nothing leaves the device without a human tap.** Messages, calendar writes, and tasks are always `proposed` until approved.
4. **Timeline events are the exception** — they write automatically. Recording needs no permission; *acting* does.
5. **API keys never in the app bundle.** All third-party AI calls go through Supabase Edge Functions.
6. **Every AI output links back to the raw capture.** A "see what I said" affordance on every card.

---

## 3. Stack

| Layer | Choice |
|---|---|
| App | Swift 6 / SwiftUI, **iOS 26 minimum**, iPhone only, portrait locked |
| Backend | Supabase — Postgres, Storage, Edge Functions (Deno/TypeScript) |
| LLM | Anthropic Claude primary, OpenAI fallback. **Both behind one interface**, selected by `LLM_PROVIDER` env var. Both are hackathon sponsors — we support both deliberately. |
| Speech-to-text | ElevenLabs Scribe via Edge Function. Apple `SFSpeechRecognizer` as offline fallback. |
| Med rules | DailyMed SPL, extracted **offline** by a Python script into a static JSON file shipped in the bundle. No runtime dependency — the demo must not depend on a third-party API being reachable. Reference data only: never advice, diagnosis or a treatment recommendation. |
| Calendar | EventKit (full access — we read the caregiver's calendar too) |
| Messaging | `wa.me` deep link; `MFMessageComposeViewController` fallback |
| PDF | SwiftUI `ImageRenderer` → PDF → `ShareLink` |
| Timers | `UNUserNotificationCenter` local notifications |

**No Python at runtime. No separate server. No auth** — a hardcoded caregiver UUID in config.

---

## 4. Conventions

- **Xcode project uses file-system-synchronised groups.** Adding a `.swift` file to a folder on disk is enough — never edit `project.pbxproj`. If a file needs to be added, just create it in the right folder.
- **Everyone commits to `main`.** Small, frequent commits. Follow `PLAN.md` commit order.
- **`Theme.swift` before any view.** No hardcoded colours, fonts, spacing or radii in feature code. Ever. Values are provisional until C13 and must all live in that one file, so a redesign is one edit. Token names are **semantic** (`ink`, `surface`, `accent`), never literal (`warmGrey`).
- **Icons are SF Symbols.** No bundled icon assets — they inherit Dynamic Type and dark mode for free.
- Timestamps: **UTC in the database, Europe/London on screen.**
- Async/await throughout. No completion handlers.
- Keep views under ~150 lines; extract subviews.

### Verify your own work

After changes, build and check yourself rather than asking the user to paste errors:

```bash
xcodebuild -scheme CareAid -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -40
```

To see the UI, boot the simulator, then screenshot and view the image:

```bash
xcrun simctl io booted screenshot /tmp/kin.png
```

---

## 5. Folder structure

```
CareAid/
├── App/            CareAidApp.swift, RootView.swift, AppState.swift, Config.swift
├── Theme/          Theme.swift, ColorToken.swift, ThemeGallery.swift
│   └── Components/ Card.swift, PrimaryButton.swift, ScreenScaffold.swift, MicButton.swift
├── Models/         Recipient, CircleMember, Medication, Capture,
│                   TimelineEvent, Artifact, Brief, ExtractionResult
├── Services/
│   ├── Supabase/   SupabaseClient.swift, *Repository.swift
│   ├── Brain/      ExtractionService.swift
│   ├── Speech/     AudioRecorder.swift, TranscriptionService.swift
│   ├── Schedule/   MedicationScheduler.swift
│   ├── Rules/      medication_rules.json, RuleStore.swift
│   └── FanOut/     CalendarService.swift, MessageService.swift,
│                   ReminderService.swift, PDFService.swift
├── Features/       Home/, Capture/, Review/, Timeline/, Schedule/, AppointmentPack/
└── Resources/
supabase/
├── migrations/     001_schema.sql, 002_seed.sql
└── functions/      extract/index.ts, transcribe/index.ts
tools/              dailymed_extract.py   (offline, never deployed)
```

---

## 6. Database schema

Postgres, in `supabase/migrations/001_schema.sql`. RLS off — single demo user.

```sql
create table recipient (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,           -- "Mum"
  legal_name text, year_of_birth int,
  conditions text[] default '{}', allergies text[] default '{}',
  gp_practice text, created_at timestamptz default now()
);

create table caregiver (
  id uuid primary key default gen_random_uuid(),
  name text not null, relation text,
  work_hours jsonb default '{}'::jsonb,  -- caregiver-first: availability constraints
  created_at timestamptz default now()
);

create table circle_member (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  name text not null, relation text,
  channel text check (channel in ('whatsapp','sms','email')),
  handle text,
  share_level text check (share_level in ('headline','summary','full')) default 'summary'
);

create table medication (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  name text not null, rxcui text, dose text,
  schedule text,                         -- "4x daily: 8am, 12pm, 4pm, 8pm"
  scheduled_times time[] default '{}',
  quantity_remaining int,
  started_on date, active boolean default true
);

create table capture (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  author_id uuid references caregiver(id),
  source text check (source in ('voice','photo','text')) not null,
  raw_text text, media_url text,
  captured_at timestamptz default now(), processed_at timestamptz,
  model_raw jsonb
);

create table timeline_event (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  capture_id uuid references capture(id),
  kind text check (kind in ('symptom','medication','incident','appointment','mood','care_task','admin')),
  occurred_at timestamptz not null,
  headline text not null,                -- <=60 chars, plain language
  detail text,
  severity int check (severity between 0 and 3) default 0,
  tags text[] default '{}', confidence numeric
);

create table artifact (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  capture_id uuid references capture(id),
  kind text check (kind in ('task','calendar_event','family_update','question','timer','medication_update')),
  payload jsonb not null,
  status text check (status in ('proposed','approved','dismissed','done','sent')) default 'proposed',
  confidence numeric,
  created_at timestamptz default now(), actioned_at timestamptz
);

create table brief (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  version int not null, content jsonb not null,
  generated_at timestamptz default now(),
  source_capture_id uuid references capture(id)
);
```

### Artifact payloads

| kind | payload |
|---|---|
| `task` | `{ title, due_at?, why }` |
| `calendar_event` | `{ title, starts_at, ends_at?, location?, notes, reminders_min: [1440,60] }` |
| `family_update` | `{ to_circle_member_id, to_name, channel, draft_text }` |
| `question` | `{ question, for_specialty, priority }` |
| `timer` | `{ label, fire_at, repeat? }` |
| `medication_update` | `{ medication_id, medication_name, field, from, to, why }` — `field` is one of `dose`, `schedule`, `active`, `quantity_remaining`. `medication_name` is carried so the card renders without a join and a mis-resolved id can be caught. |

Approving a `medication_update` writes to the `medication` table, which is what the Schedule screen and the C12 scheduler read. Without it the brief and the schedule drift apart silently.

### Brief content

```json
{
  "one_liner": "...",
  "current_concerns": [{ "text": "...", "since": "2026-07-02", "trend": "worsening" }],
  "medications": [{ "name": "...", "dose": "...", "schedule": "...", "adherence_note": "..." }],
  "recent_changes": ["..."],
  "open_questions": ["..."],
  "whats_working": ["..."]
}
```

---

## 7. The extraction contract

**One LLM call per capture. Not a chain.** Edge Function `extract`.

**Context assembled server-side and injected:** recipient profile, active medications with scheduled times, circle members *by name and relation* (so the model resolves "Tom" → a `circle_member_id`), upcoming appointments, current brief, last 90 days of timeline headlines (one line each — this is what makes pattern detection possible), and current datetime in Europe/London.

**The model never touches the database.** No tools, no function calling, no agentic loop. The Edge Function queries Postgres itself and injects the results as text. One call in, one JSON object out — predictable latency, and the model physically cannot write anything.

**The Edge Function owns every extraction write.** It validates the model's JSON against the `CHECK` constraints in §6, inserts `timeline_event` rows (auto-committed) and `artifact` rows (`proposed`), stamps `capture.processed_at`, stores the raw response in `capture.model_raw`, then returns the persisted rows **including their ids**. The app never inserts events or artifacts itself; it reads, and it PATCHes `artifact.status` on approval. Re-running `extract` for a capture replaces that capture's rows, so a retry can never double-write.

`patterns` and `flags` have no table. They ride back in the response to drive the Review sheet, and are recoverable from `model_raw`.

**Response schema.** The LLM emits exactly this; the app receives the same shape with database ids added. Mirror both as Swift `Codable` structs:

```json
{
  "events": [
    { "kind": "medication", "occurred_at": "2026-07-24T20:00:00Z",
      "headline": "Evening co-careldopa dose missed",
      "detail": "Found still in the tray.",
      "severity": 2, "tags": ["adherence"], "confidence": 0.9 }
  ],
  "artifacts": [
    { "kind": "task", "confidence": 0.95,
      "payload": { "title": "Ring the surgery about Mum's evening dose",
                   "due_at": "2026-07-27T09:00:00Z",
                   "why": "Third missed evening dose this month" } }
  ],
  "brief_patch": {
    "one_liner": "...", "add_concerns": [], "resolve_concerns": [], "medication_changes": []
  },
  "patterns": [
    { "observation": "Third missed evening dose this month", "evidence_event_ids": [] }
  ],
  "flags": [
    { "type": "ambiguous_date", "text": "the 14th", "ask": "Is the neurology appointment 14 August?" }
  ]
}
```

**System prompt rules (put these in the Edge Function):**

1. Never diagnose, never suggest a cause, never recommend a treatment or dose. Record what the human said; do not interpret it medically.
2. Never invent a fact not in the capture or the supplied context. Low confidence → emit a `flag`, not a guess.
3. Use circle members' real names in drafted messages. Match the caregiver's register — warm, plain, short. Three sentences maximum.
4. Resolve relative times ("last night", "the 14th") against the supplied datetime. If ambiguous, flag it.
5. `headline` ≤ 60 characters, plain English, no clinical jargon the caregiver didn't use themselves.
6. If something may need urgent attention, emit a `possible_escalation` flag whose action is "call 111 or the GP" — never a cause.
7. Return JSON only, matching the schema exactly.
8. Only emit a `medication_update` when the capture states the change outright — who changed it, and to what. Never infer one from a symptom, a missed dose or a pattern. If a change is implied but not stated, emit a `flag` instead. Phrase `why` as attribution ("Sarah said Dr Okafor increased it"), never as rationale.

---

## 8. Design constraints

The user is **tired**, possibly at 3am, one-handed, and may be 50–75 with presbyopia. Design for exhaustion, not just for age.

- **Type:** body 19–20pt minimum (above the 17pt default). Card headlines 22pt. Brief one-liner 30pt. Support Dynamic Type throughout.
- **Touch targets:** 56pt minimum. Primary actions 72pt tall.
- **Contrast:** body text ≥ 7:1. No grey-on-grey.
- **Liquid Glass on chrome only** — nav bars, toolbars, the mic button. **Content cards are solid and opaque.** Never put body text on glass; it's low-contrast by nature and our user can't afford that.
- **No modals, no nested navigation deeper than two levels, no gesture-only actions.** Every action is a visible button.
- **Language:** "Tell Tom", not "Send family update". "Put it in the diary", not "Create calendar event". "Not this", not "Reject". Human dates: "this morning", "yesterday evening".
- **One animation, used once:** the card stagger on the Review screen, 200ms. Nothing else moves.
- **Never lose input.** Persist the transcript before the LLM call. If extraction fails, the raw note survives and is visible.
- Auto dark mode after 21:00.

### Screens

1. **Home** — mic button dominant and centred. Above it "How's Mum?". Below, today's timeline strip (3 items max) and the next two upcoming things — both tappable through to their full screens. Small icons top for Timeline / Schedule / Appointments. Secondary buttons for keyboard and camera. **This is not a chat UI** — no bubbles, no scrolling transcript, no AI reply on screen.
2. **Capture** — live waveform, transcript appears as it comes, cancel always available. Never a blank spinner.
3. **Review** (full-screen sheet after capture) — transcript pinned at top in quotes. Then cards, staggered in: first the auto-committed record entry (greyed, no action), then the proposals. Each: plain-language headline, detail, one large primary button, one small "Not this". A pattern banner above if `patterns` is non-empty. "Approve all" at the bottom.
4. **Timeline** — reverse chronological, grouped by day, human date labels. Brief pinned at top as a card.
5. **Schedule** — medication times, conflicts flagged, caregiver's busy blocks visible.
6. **Appointment Pack** — question bank + "Make the pack" → PDF via `ShareLink`.

---

## 9. Demo script — build backwards from this

The whole app exists to make this 25-second recording work:

> "Right, so — Mum had a bad night, she was up at three again and she'd forgotten her evening Sinemet, I found it still in the tray. She seemed a bit confused this morning but she's better now. I said I'd ring the surgery about the dose because this is the third time this month. Oh, and Tom's asking how she is. Her neurology thing is the 14th isn't it — I need to remember to ask them about the night-time freezing."

Must produce: (1) timeline entry, auto — (2) task: ring the surgery, due Monday — (3) drafted WhatsApp to Tom — (4) question for neurology re night-time freezing — (5) calendar event, Dr Okafor, 14 August — (6) pattern banner: *"That's the third missed evening dose this month."*

The pattern banner **only works because seeded history exists.** Seed data is not optional.

---

## 10. Out of scope for V0 — do not build

Auth. Onboarding. Settings. Multiple care recipients. Editing cards before approval (approve/dismiss only — the schedule screen is the one exception). Push notifications from a server. iPad. Landscape. A landing page. Dark mode toggle (auto only). Anything touching a real NHS or EHR API.
