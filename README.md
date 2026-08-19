# CareAid

*Say it once. We do the rest.*

CareAid is a caregiver-first iOS app. A caregiver speaks one messy, tired thought — the app turns it into a timeline entry, a calendar event, a drafted WhatsApp message to a family member, a task, and a question for the next doctor's appointment. One input, five destinations, four taps.

Every other tool makes you pick the destination first. CareAid takes the routing away, and it schedules medication around **the caregiver's** real life — their work meetings, their commute — not just the patient's.

Built as a hackathon project. See [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) for the full product brief and non-negotiable rules, and [`PLAN.md`](PLAN.md) for the build plan and current progress.


## Non-negotiable rules

1. **Never medical advice.** CareAid records what a human said and routes it — it never diagnoses or recommends treatment or dose. Timing conflicts surface as a question for a pharmacist or GP, never an instruction.
2. **All data is synthetic.** No real patient data, ever.
3. **Nothing leaves the device without a human tap**, except timeline events, which record automatically — recording needs no permission, acting does.
4. **API keys never ship in the app.** All third-party AI calls go through Supabase Edge Functions.
5. **Every AI output links back to the raw capture** it came from.

## Stack

| Layer | Choice |
|---|---|
| App | Swift 6 / SwiftUI, iOS 26 minimum, iPhone only, portrait locked |
| Backend | Supabase — Postgres, Storage, Edge Functions (Deno/TypeScript) |
| LLM | Anthropic Claude primary, OpenAI fallback, behind one interface (`LLM_PROVIDER`) |
| Speech-to-text | `transcribe` Edge Function — OpenAI or ElevenLabs Scribe behind `STT_PROVIDER` — with Apple `SFSpeechRecognizer` live on screen and as the fallback |
| Med rules | DailyMed SPL data, extracted offline into a static JSON file shipped in the bundle |
| Calendar | EventKit |
| Messaging | `wa.me` deep link, with `MFMessageComposeViewController` fallback |
| PDF | SwiftUI `ImageRenderer` → PDF → `ShareLink` |
| Reminders | `UNUserNotificationCenter` local notifications |

No Python at runtime, no separate server, no auth — a hardcoded demo caregiver/recipient UUID pair in config.

## Project structure

```
CareAid/
├── App/            App entry point, root view, app state, config
├── Theme/          Design tokens and shared UI components
├── Models/         Codable models shared with the Supabase schema
├── Services/
│   ├── Supabase/   Client wrapper and table repositories
│   ├── Brain/      Extraction service client
│   ├── Speech/     Audio recording and transcription
│   ├── Schedule/   Caregiver-aware medication scheduler
│   ├── Rules/      Offline-extracted medication timing rules
│   └── FanOut/     Calendar, messaging, reminders, PDF export
├── Features/       Home, Capture, Review, Calendar, Medications
└── Resources/
supabase/
├── migrations/     Postgres schema and synthetic seed data
└── functions/      extract/ and transcribe/ Edge Functions
tools/              dailymed_extract.py — offline only, never deployed
```

## Getting started

### Prerequisites

- Xcode with iOS 26 SDK
- A Supabase project (Postgres + Edge Functions)
- [Supabase CLI](https://supabase.com/docs/guides/cli) for running migrations and deploying functions

### 1. Configure Supabase credentials

```bash
cp CareAid/Resources/Supabase.example.plist CareAid/Resources/Supabase.plist
```

Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project's dashboard (Settings → API). `Supabase.plist` is gitignored — never commit it. Row-level security is off for this demo, which makes the anon key a full read/write credential, not a public one, so keep it out of source control and screenshots.

Third-party AI keys (Anthropic, OpenAI, ElevenLabs) never go in the app. They're set as Supabase Edge Function secrets and only read server-side.

### 2. Set up the database

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

This applies `supabase/migrations/001_schema.sql` and seeds synthetic demo data (`002_seed.sql`) for the demo persona set — Margaret, Sarah, Tom, Joy and Dr Okafor.

### 3. Deploy the Edge Functions

```bash
supabase functions deploy extract
supabase functions deploy transcribe
supabase secrets set ANTHROPIC_API_KEY=... OPENAI_API_KEY=... ELEVENLABS_API_KEY=... LLM_PROVIDER=anthropic
```

### 4. Build and run

Open `CareAid.xcodeproj` in Xcode and run on an iPhone simulator or device, or from the command line:

```bash
xcodebuild -scheme CareAid -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Conventions

- The Xcode project uses file-system-synchronised groups — add a `.swift` file to the right folder on disk and it's picked up automatically. Don't hand-edit `project.pbxproj`.
- All colours, spacing, type and radii live in `Theme.swift` as semantic tokens (`ink`, `surface`, `accent`) — never hardcoded or literal names in feature code.
- Icons are SF Symbols only, for free Dynamic Type and dark mode support.
- Timestamps are stored UTC, displayed Europe/London.
- Async/await throughout, no completion handlers.

## Development tooling

This repository includes a [`CLAUDE.md`](CLAUDE.md) project brief for use with [Claude Code](https://claude.com/claude-code).
