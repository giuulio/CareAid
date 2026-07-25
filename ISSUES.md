# Known Issues

Recorded from a code audit on 2026-07-25. Not fixed yet — flagged here with enough detail to
pick up later without re-deriving the investigation.

## 1. Duplicate calendar events on retry (data-corruption)

**Where:** `CareAid/Services/FanOut/CalendarService.swift:32-56`, called from
`CareAid/Features/Review/ReviewViewModel.swift:54-63` (`approve`).

`ReviewViewModel.approve()` calls `CalendarService.add()` (which creates an `EKEvent`) *before*
marking the artifact `approved`. If the calendar write succeeds but the subsequent status PATCH
fails (e.g. dropped connection), the card is shown as `.failed` with a "Try again" button.
Tapping it re-runs `perform()`, and `CalendarService.add()` has no dedup key — it creates a
brand-new `EKEvent` every call. Result: duplicate appointments in the caregiver's real calendar.

Contrast with `ReminderService.swift:57-58`, which deliberately keys its `UNNotificationRequest`
on `artifact.id` "so approving twice replaces rather than stacking two identical reminders" —
`CalendarService` needs the same treatment (e.g. store/check an event identifier keyed on
`artifact.id` before creating a new `EKEvent`).

## 2. `medication_update` cannot patch `scheduled_times` (data-model mismatch)

**Where:** `CareAid/Models/Enums.swift:49-54` (`MedicationField`), mirrored in
`supabase/functions/extract/schema.ts:117`; write path in
`CareAid/Services/Supabase/MedicationRepository.swift:29-35`.

The `field` enum only covers `dose`, `schedule`, `active`, `quantity_remaining` — never
`scheduled_times`. So a caregiver-reported change like "she's now on 3x daily instead of 4x"
updates `medication.schedule` (the display string) but leaves `medication.scheduled_times` (the
`time[]` array the scheduler and Schedule screen are meant to read, per CLAUDE.md §6) untouched.

This is exactly the brief/schedule drift CLAUDE.md warns about: "Approving a `medication_update`
writes to the `medication` table, which is what the Schedule screen and the C12 scheduler read.
Without it the brief and the schedule drift apart silently." The write path exists and is wired
to approval, but it structurally cannot keep both representations in sync. Currently latent
because `Features/Schedule/ScheduleView.swift` is still a stub (see #3) — will surface as
silently-wrong reminder times the moment the real scheduler is built against the current schema.

## 3. Schedule screen is an unwired stub (dependency note, not a bug)

**Where:** `CareAid/Features/Schedule/ScheduleView.swift`, `Services/Schedule/`,
`Services/Rules/` (placeholders / `.gitkeep` only).

Not a bug by itself — noted because it's why #2 isn't visibly broken yet. Check #2 before or
while building the C12 scheduler on top of this.

## 4. Untyped JSON values in `MedicationRepository.update` (possible failure on approve)

**Where:** `CareAid/Services/Supabase/MedicationRepository.swift:29-35`.

Values are sent via `.update([field.rawValue: value])` as JSON strings for every field, including
`active` (bool) and `quantity_remaining` (int) columns. The code comment assumes
Postgres/PostgREST will cast a JSON string to boolean/int on write; this is fragile and
version-dependent rather than guaranteed. If it fails, `approve()` surfaces as `.failed` (not
silent corruption), but it's worth a targeted integration test before demo day.

## 5. No `proposed`-status guard in `FanOutService.perform` (minor)

**Where:** `CareAid/Services/FanOut/FanOutService.swift:13-39`.

Never checks `artifact.status == .proposed` before acting — it trusts the caller. Currently safe
because the only caller (`ReviewViewModel`) sources artifacts from `ArtifactRepository.proposed()`,
but there's no guard rail if a stale `Artifact` value is re-passed to `approve()` later (e.g. from
a cached view model) — it would re-fire a WhatsApp draft or calendar write. Easy to harden:
check `artifact.status == .proposed` at the top of `perform`.

---

**Aside:** the original "won't launch in Xcode" report (a colleague's issue) could not be
reproduced in this environment — no Xcode.app installed here, only Command Line Tools, so
`xcodebuild` can't run. Static inspection of `project.pbxproj` (file-system-synchronized group,
`Info.plist` handling via `EXCLUDED_SOURCE_FILE_NAMES`, `Package.resolved`) turned up nothing
wrong. If it recurs, get the exact Xcode error text or console output rather than re-deriving
from the project file alone.
