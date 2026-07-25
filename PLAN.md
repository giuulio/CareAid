# CareAid — Build Plan

Work through these **in order**. One commit each, message given. After each commit: build must succeed, app must launch. Never move on from a broken state.

Priority: **P0** = required for the demo. **P1** = the differentiator, build if C0–C10 are done. **P2** = only if genuinely ahead.

---

### C0 · Repo hygiene — P0
Swift `.gitignore` (exclude `xcuserdata/`, `.DS_Store`, `.env`). `Config.swift` reading Supabase URL + anon key from a plist, plus hardcoded demo UUIDs for caregiver and recipient. Confirm the Xcode project uses **file-system-synchronised groups**; if not, convert it. Create the folder structure from `CLAUDE.md` §5 with `.gitkeep` files.
`chore: project scaffolding and config`

### C1 · Theme and components — P0
`Theme.swift`: colour, spacing, type-scale, radius and size tokens as constants. **Semantic names** (`ink`, `surface`, `accent`) — never literal ones (`warmGrey`), so the palette can move without touching a view. Light and dark values defined together, one token at a time. Warm paper base, near-black ink, one accent — **provisional values, retuned in C13**.

Components: `Card`, `PrimaryButton` (72pt), `SecondaryButton`, `ScreenScaffold`, `MicButton`. **Icons are SF Symbols only** — no bundled icon assets. Nav shell with the three top icons and three stub screens. A `ThemeGallery` debug screen renders every token on one page so C13 is a visual edit, not a hunt.
**Every later view uses these tokens. No hardcoded values anywhere.**
`feat: theme tokens, base components, navigation shell`

### C2 · Models — P0
All `Codable` structs from `CLAUDE.md` §6 and §7. Snake_case ↔ camelCase via `CodingKeys`. Dates as ISO8601 UTC. `kind` and `severity` become Swift enums whose raw values match the §6 `CHECK` constraints exactly, so an invalid value fails at decode rather than at insert.

`artifact.payload` is an **enum with associated values**, decoded by switching on `kind` — C8's fan-out switches on the same thing, and this way the compiler catches a missing case.

Per §7 the Edge Function does the writing, so the app needs the row models plus one response envelope — no separate "unsaved" variants.
`feat: data models and extraction schema`

### C3 · Database — P0
`supabase/migrations/001_schema.sql` (verbatim from §6) and `002_seed.sql`. Seed must be **idempotent and re-runnable** — truncate then insert; we'll reset twenty times tonight.

Seed: Margaret, Sarah (work hours Mon–Fri 09:00–17:30, standup 09:00–09:30), Tom (whatsapp), Joy (07:30/18:00 visits), 8 medications with realistic Parkinson's + AF polypharmacy, Dr Okafor appointment 14 Aug, and **90 days of timeline events** — including exactly three missed evening levodopa doses in the current month, spaced realistically.
`feat: database schema and synthetic seed data`

### C4 · Supabase client — P0
Add `supabase-swift` via SPM. Client wrapper plus repositories for each table. Timeline screen renders real seeded data from the DB.
**Checkpoint: seeded history visible on device.**
`feat: supabase client, repositories, timeline reads live data`

### C5 · Extraction Edge Function — P0
`supabase/functions/extract/index.ts`. Assembles context per §7, calls the LLM, **writes the results, and returns the persisted rows with their ids**. **Provider behind one interface, `LLM_PROVIDER` env var** — Anthropic primary, OpenAI fallback, both implemented. Keys as Supabase secrets, never in the app. Validate the response shape and repair-or-retry once on malformed JSON. Writes are keyed on `capture_id` and replace any previous rows for that capture, so a retry is safe.
`feat: extraction edge function with anthropic and openai providers`

### C6 · Text capture → persist — P0
Typed capture → `capture` row (written **before** the LLM call, so the note survives a failed extraction) → call `extract` → decode the returned rows. The function does the inserting; the app decodes and displays. No UI beyond a debug text field yet.
`feat: text capture pipeline end to end`

### C7 · Review sheet — P0
The card stack. Auto-committed record entry first (greyed), then proposals with approve / "Not this". Pattern banner when present. "See what I said" expands the raw transcript. Approve-all. 200ms stagger.
**This is the demo's centrepiece — spend the time.**
`feat: review sheet with proposal cards and approve flow`

### C8 · Fan-out — P0
Approving an artifact does the real thing:
- `calendar_event` → EventKit `EKEvent` + `EKAlarm` (request **full** access, not write-only)
- `family_update` → `wa.me` deep link via `openURL`, `MFMessageComposeViewController` fallback
- `task` → local `UNUserNotificationCenter` notification
- `question` → appointment question bank

Add Info.plist keys now: `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSCameraUsageDescription`, `LSApplicationQueriesSchemes: [whatsapp]`.
`feat: fan-out to calendar, whatsapp, reminders, question bank`

### C9 · Voice capture — P0
`AVAudioRecorder` → upload to Supabase Storage → `transcribe` Edge Function (ElevenLabs Scribe) → transcript → `extract`. **Apple `SFSpeechRecognizer` as automatic fallback if the network fails** — conference wifi kills more demos than bugs do. Live waveform. Transcript persists before the LLM call.
`feat: voice capture with elevenlabs transcription and on-device fallback`

### C10 · Brief and appointment pack — P0
Apply `brief_patch` to the current brief on each capture. Brief card at the top of Timeline, rendered in a serif so it reads as a document. Appointment Pack screen: question bank + "Make the pack" → SwiftUI `ImageRenderer` → PDF → `ShareLink`. Pack contains brief, last 30 days of relevant events, medication list, questions.
**Checkpoint: full demo runs end to end, ugly. If it doesn't, stop and fix before anything below.**
`feat: living brief and appointment pack pdf`

### C11 · Medication rules — P1
`tools/dailymed_extract.py` — offline only, never deployed. For each seeded medication: RxNorm normalise → RxCUI → DailyMed SPL v2 (`https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json?rxcui=...`) → pull the **Dosage and Administration** section (not Drug Interactions — that's pharmacology prose and a swamp; administration is where "empty stomach", "with food", "separate by 4 hours" live). Extract timing rules to `medication_rules.json`, **keeping the exact source sentence and setid for citation**. Human-check the output before committing. `RuleStore.swift` loads it from the bundle.
`feat: dailymed-sourced medication timing rules`

### C12 · Caregiver-first scheduler — P1
`MedicationScheduler.swift`. Greedy constraint solver:
- **Hard:** label rules (empty stomach, separation windows, with/without food)
- **Hard:** caregiver availability — **read the device calendar via EventKit** and treat busy blocks as unavailable
- **Soft:** minimise separate administration events; stay near prescribed times; cluster on meals and Joy's visits

Schedule screen shows before/after and flags conflicts. **A conflict never changes a schedule — it emits a `question` artifact** ("Ask the pharmacist: Mum's levothyroxine is at 8am with her calcium; the label says to separate these — is her timing right?"). Manual override on this screen only.
`feat: caregiver-aware medication scheduler`

### C13 · Design pass — P0
Retune the values in `Theme.swift` against the real screens — every colour, size and spacing decision from C1 was provisional and lives in that one file. Work from `ThemeGallery`. (If a Figma file with exported tokens ever materialises, this is where its values land — but nothing before this point depends on one existing.) Full typography, spacing and colour pass across all screens. Liquid Glass on chrome, solid opaque content cards. Verify contrast and 56pt touch targets. Empty states. Loading states that show the transcript, never a bare spinner.

The §8 accessibility floors are **not** provisional: 19–20pt body, 22pt card headlines, 56pt touch targets, 72pt primary actions, 7:1 body contrast. Tune around them, not through them.
**Do not skip this. It is where the prize is.**
`style: design pass`

### C14 · Demo hardening — P0
Pre-grant every permission on the demo device. Graceful failure on every network call. Reset-and-reseed script. Run the demo script five times, fix only demo-path bugs. Record a backup video on the physical device.
`chore: demo hardening and fallbacks`

---

## Cut ladder

If behind, sacrifice in this order: C12 → C11 → photo capture → timers → animations → the Schedule screen entirely.

**Never cut:** C7 (review sheet), C10 (PDF), C13 (design pass).

## Rules

- Feature freeze **three hours** before submission.
- Backup video recorded **before** anyone sleeps.
- Submit 45 minutes early.
