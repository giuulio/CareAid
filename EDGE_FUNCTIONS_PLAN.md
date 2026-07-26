# Plan: `extract` and `transcribe` Edge Functions

---

> ## STATUS: `extract` is built, deployed and verified — don't rebuild it
>
> This plan was written when both functions were `.gitkeep` placeholders. That
> is no longer true for `extract` (commits `4ce5ee0`, `f68b82d`). **`transcribe`
> is still unbuilt and this plan remains the right guide for it.**
>
> The analysis above and below was independently correct — it derived the same
> wire contract from the Swift models, and the verification steps were followed
> almost exactly. Live result against the §9 demo capture: **all six required
> outputs present**, correct London↔UTC conversion, and re-running the same
> `capture_id` replaced rows rather than doubling them.
>
> **Where the built version differs from this plan, and why:**
>
> - **Flat `extract/` layout, no `_shared/`.** Only one function exists so far;
>   `_shared` can be introduced when `transcribe` lands and there is something
>   to actually share.
> - **The schema is enforced by the API, not hand-validated.** Both providers
>   support structured outputs, so the ~40-line checker isn't needed for shape.
>   One consequence: OpenAI's strict mode rejects `anyOf`, so the model returns
>   **per-kind artifact arrays** which the function flattens into `artifact`
>   rows. The response the app sees is unchanged. See CLAUDE.md §7.
> - **No automatic provider failover.** `LLM_PROVIDER` selects one, matching
>   CLAUDE.md §3's "selected by `LLM_PROVIDER` env var". Worth revisiting — but
>   note it would be dead code today: only OpenAI is funded, so failing over to
>   Anthropic would just fail differently. Revisit if an Anthropic key lands.
> - **`medication_changes` folds into `recent_changes`, not `medications`.**
>   Both are guesses at an underspecified field; `recent_changes` is `[String]`
>   so the patch entries drop straight in, where matching into `medications` by
>   name needs parsing prose into structured fields. Flagging as an
>   interpretation, same as this plan does.
> - **Hallucinated-ID guard adopted from this plan** — good catch, now
>   implemented in `persist.ts`.
>
> **Still open from this plan:** the `captures` Storage bucket and the
> `capture.media_url` write path for photo capture.
>
> ## STATUS: `transcribe` is built, deployed and verified too
>
> Built without the Storage bucket, which this plan treated as a blocker. It
> isn't one: the app **posts the audio as the raw request body** and the
> function forwards it to the transcriber. The signed-URL flow needed a bucket,
> an upload, a URL and a fetch before the first byte reached a transcriber —
> four things to fail in the one part of the demo where Sarah has just stopped
> talking and is waiting. One hop instead. The bucket is still worth creating
> for photo capture, which genuinely needs a durable URL.
>
> Two other deviations, both deliberate:
>
> - **OpenAI, not ElevenLabs, by default.** `STT_PROVIDER` picks between them
>   the way `LLM_PROVIDER` does, and Scribe is implemented — but the ElevenLabs
>   credits aren't redeemed and the OpenAI key already is. One env var when they
>   land.
> - **The function reads her record for a vocabulary hint.** Medication names,
>   circle members and appointment headlines, straight from Postgres. Without it
>   "co-careldopa" comes back as three unrelated words and "Okafor" as "okay
>   for". Nothing invented: if it isn't in the database it isn't in the hint.
>
> Verified end to end on 2026-07-26: spoken audio → transcript with "Sinemet",
> "25/125" and "Dr Okafor" correct → `extract` → the three demo cards.

---

## Context

CareAid's entire product idea — "say it once, we do the rest" — depends on one Supabase Edge Function, `extract`, turning a caregiver's raw capture into timeline events and proposed artifacts. Right now `supabase/functions/extract/` and `supabase/functions/transcribe/` contain only `.gitkeep` placeholders; nothing has been built or deployed (`list_edge_functions` on the live project `prpuxfpkxdsuxjihkkdt` returns zero functions). Everything upstream is ready and waiting: the DB schema and seed data are live and correct, and the Swift `Codable` models the app will eventually decode (`ExtractionResponse`, `Artifact`, `Brief`, `Coding.swift`) are already fully written and fixed — they define the exact wire contract this plan must produce. This plan is scoped **only** to the two Edge Functions (backend). Building the Swift-side Capture/Review/Speech/FanOut/Scheduler code that will eventually call these functions is explicitly deferred to later work.

Because nothing calls these functions yet, their *request* shape is ours to design; their *response* shape (for `extract`) is fixed by the Swift models and must match exactly, field-for-field, or the app will fail to decode at runtime with no compile-time warning.

**Update:** a follow-up alignment pass against the live project turned up one blocker for `transcribe` specifically — `select * from storage.buckets` on `prpuxfpkxdsuxjihkkdt` returns empty. **No Storage bucket exists at all**, so `transcribe`'s planned flow (generate a signed URL for an uploaded audio file) has nothing to point at yet. This also affects `capture.media_url`, a real schema column with no write path anywhere in the Swift code — `photo` is a valid `capture.source`, but nothing uploads a photo to Storage or populates that column. Bucket creation is now folded into this plan as a prerequisite step for `transcribe` (see "Storage bucket" under Approach). Everything else checked out: an Explore pass grepping all Swift files under `Services/Supabase/` for table names, column names, `.storage.from(...)` calls, and `.rpc(...)` calls found zero mismatches against `001_schema.sql` and zero hidden bucket/RPC dependencies.

## Verified wire contract (read directly from source, not assumed)

- `ExtractionResponse` top-level keys: `capture_id, events, artifacts, patterns, flags, brief` — **note: `brief`, not `brief_patch`**. The function must apply the LLM's `brief_patch` to the current brief and persist a new `brief` row (`version = previous + 1`), returning that full persisted row under `brief`. `brief` may be omitted/null if there's no patch.
- Each artifact in the response is `{id, recipient_id, capture_id, kind, payload, status, confidence, created_at, actioned_at}` — `kind` is a **sibling** of `payload`, not nested inside it (confirmed in `Artifact.swift`'s custom decoder).
- Payload field names per kind (exact, snake_case on the wire):
  - `task`: `title, due_at?, why`
  - `calendar_event`: `title, starts_at, ends_at?, location?, notes?, reminders_min:[Int]`
  - `family_update`: `to_circle_member_id?, to_name, channel, draft_text`
  - `question`: `question, for_specialty?, priority?`
  - `timer`: `label, fire_at, repeat?` (JSON key is literally `"repeat"`)
  - `medication_update`: `medication_id, medication_name, field (dose|schedule|active|quantity_remaining), from?, to, why`
- Timestamps: the app's decoder (`Coding.swift`) accepts plain ISO8601 (`2026-07-24T20:00:00Z`) or ISO8601-with-fractional-seconds — **always emit UTC with a literal `Z`**. `date` columns need `yyyy-MM-dd`; `time` columns need `HH:mm[:ss]`.
- `BriefContent` has no `medication_changes` field (only `medications: [BriefMedication]`), even though CLAUDE.md's example `brief_patch` includes one. Resolve by folding `medication_changes` entries into updates of the `medications` array (matched by name) when merging the patch — document this as an interpretation, since it's not spelled out anywhere.
- `Flag.type` is an open string wrapper (not DB-constrained) — no need to validate against a fixed set. `timeline_event.kind`, `artifact.kind`, and `medication_update.field` **are** DB-CHECK-constrained and must be validated strictly before insert.
- DB writes: `.select()` results from Postgres/PostgREST come back snake_case already, matching the Swift `CodingKeys` directly — no manual field renaming needed for persisted rows, only for the top-level response envelope.

## Approach

### File layout

```
supabase/
  functions/
    _shared/
      cors.ts              # shared CORS headers
      types.ts             # shared TS types for the LLM output + persisted rows
      llm/
        provider.ts         # LLMProvider interface, primary/fallback selection
        anthropic.ts         # Claude implementation (plain fetch, no SDK)
        openai.ts             # OpenAI implementation (plain fetch, JSON mode)
      extraction/
        context.ts           # assembleContext(recipientId) -> ContextBundle
        prompt.ts             # buildSystemPrompt(), buildUserPrompt(ctx, rawText)
        schema.ts               # validateExtractionJSON(obj)
        persist.ts                # replaceCaptureResults(...)
    extract/index.ts       # thin HTTP orchestrator
    transcribe/index.ts    # thin HTTP orchestrator
```

Before writing to `_shared/`, check whether `mcp__claude_ai_Supabase__deploy_edge_function` accepts multi-file bundles with relative imports, or only a single file — this determines whether `_shared/` survives as real deployed files or needs to be inlined per function at deploy time. Author with `_shared/` regardless, for local clarity/version control.

Skip `supabase/config.toml` (only needed for local `supabase functions serve`, not used here). A minimal `deno.json` is worth adding purely for editor type-checking (`Deno.serve`, `Deno.env`).

### `extract/index.ts` — request/response flow

Request: `{ capture_id: string }`. The function always re-reads `raw_text` from the `capture` row (already written client-side before this call, per the "never lose input" rule) rather than accepting raw text directly — keeps retries idempotent (`POST` the same `capture_id` again).

Flow:
1. Look up `capture` by id; 404 if missing, 422 if `raw_text` is null.
2. `assembleContext(recipientId)` — parallel queries: recipient profile, active medications, circle members, next few upcoming appointments (`timeline_event` kind=`appointment`, future), current brief (latest version), last 90 days of timeline headlines (chronological, one line each), plus current datetime computed for Europe/London via `Intl.DateTimeFormat`.
3. Build system + user prompts (`prompt.ts`) encoding CLAUDE.md §7's 8 rules, the exact output schema/vocabulary (event kinds, artifact kinds, payload shapes, severity range), and "return JSON only, no markdown fences."
4. Call the LLM via the dual-provider abstraction (below), get back parsed+validated JSON.
5. `replaceCaptureResults(...)`: delete any existing `timeline_event`/`artifact` rows for this `capture_id` (retry-safety), insert new `timeline_event` rows (auto-committed), insert new `artifact` rows (always `status='proposed'` — rule 3), merge `brief_patch` into a new `brief` version if present, stamp `capture.processed_at` + `capture.model_raw` (raw LLM text + provider + parsed JSON — no Swift model reads this, so it's free-form).
6. Return `{capture_id, events, artifacts, patterns, flags, brief}` with real DB ids from the insert `.select()` results.

### Dual-provider LLM abstraction (`_shared/llm/`)

```ts
interface LLMProvider {
  name: "anthropic" | "openai";
  complete(system: string, user: string): Promise<{raw: string; provider: string}>;
}
```

`primaryProvider(env)` / `fallbackProvider(env)` pick based on `LLM_PROVIDER` (default `anthropic`; **as built, defaults to `openai` instead — see STATUS banner above, no fallback provider implemented**). Plain `fetch()` calls — no SDK dependency, keeps the Deno bundle small:
- Anthropic: `POST /v1/messages` with `anthropic-version` header.
- OpenAI: `POST /v1/chat/completions` with `response_format: {type: "json_object"}` for a real JSON-mode guarantee.

Call orchestration (at most 3 LLM calls total — no over-engineered retry loop):
1. Call primary. If HTTP/network failure → skip straight to fallback.
2. If primary returns malformed/invalid JSON → one repair attempt with the same provider (append a "your JSON was invalid, error: X, return corrected JSON only" nudge).
3. If still invalid → call fallback provider once.
4. If all three attempts fail → throw (surfaced as a 500).

Validation (`schema.ts`) is a hand-rolled ~40-line checker (no schema library needed): checks `kind` values against the DB CHECK-constraint sets, `severity` range, `headline` length ≤60, required fields per artifact payload kind. Cross-reference `medication_update.medication_id` and `family_update.to_circle_member_id` against ids actually present in the assembled context — if a referenced id doesn't exist, drop that one artifact (don't fail the whole batch) since the model may hallucinate a UUID.

**As built:** `schema.ts` holds the JSON-Schema passed to the provider for structured-output enforcement (shape is guaranteed, not hand-checked) rather than the post-hoc checker described above; the hallucinated-ID guard was adopted as planned and lives in `persist.ts`.

### Storage bucket (prerequisite for `transcribe`)

No bucket exists yet on the live project — `transcribe` cannot function until one does. Create a `captures` bucket before deploying `transcribe`:

```sql
insert into storage.buckets (id, name, public)
values ('captures', 'captures', false)
on conflict (id) do nothing;
```

Keep it **private** (`public = false`) — consistent with RLS being off elsewhere for the demo, but audio recordings and photos are exactly the kind of blob that shouldn't be world-readable by URL guessing even in a synthetic-data hackathon build. `transcribe` reads it server-side with the service-role key via a short-lived signed URL (already in its design below), so privacy costs nothing functionally. Since RLS is off / no auth exists, Storage's own bucket-level policies aren't strictly needed for the demo, but leaving the bucket private is a one-line difference from public and avoids the anon key doubling as a way to enumerate/download every recording.

This also unblocks (but does not itself implement) photo capture: `capture.media_url` is a real schema column with no current write path — out of scope for this plan, but worth flagging so whoever builds photo capture later knows the bucket will already exist.

### `transcribe/index.ts`

Request: `{ storage_path: string, bucket?: string }` (default bucket `"captures"`). Flow: generate a short-lived signed URL server-side for the audio (service-role key), fetch it, POST as multipart form to ElevenLabs Scribe (`https://api.elevenlabs.io/v1/speech-to-text`), return `{ transcript: string }`. Explicit error handling: missing/invalid path → 400, not found in storage → 404, storage fetch failure → 502, ElevenLabs non-2xx → 502 with the response body passed through for debugging. Empty transcript is not an error — return it and let the (future) client decide, consistent with "never lose input."

### Secrets

Set via `mcp__claude_ai_Supabase__deploy_edge_function` or the Supabase dashboard (never in git, never in the app bundle):
- `LLM_PROVIDER` (`anthropic` | `openai`, default `anthropic`; **as built, default is `openai`** — only OpenAI is funded, per STATUS banner)
- `ANTHROPIC_API_KEY`
- `OPENAI_API_KEY`
- `ELEVENLABS_API_KEY`

`SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by the platform into every Edge Function — do not set manually. Add an `.env.example` at repo root documenting the four custom keys (placeholders only) for whoever fills in real secrets. **Not yet created** as of this status pass.

### Not blocking, optional cleanup

Supabase's performance advisor flags a handful of `INFO`-level items unrelated to these two functions, surfaced by the same alignment pass: `capture.author_id`, `capture.recipient_id`, `circle_member.recipient_id`, `medication.recipient_id`, and `brief.source_capture_id` have no covering index on their foreign key. Harmless at current (seed-data) row counts and not worth spending hackathon time on, but a one-line `create index` each if this ever needs to handle real query volume. Not part of this plan's scope.

## Critical files

- ✅ `supabase/functions/extract/index.ts` — built (flat layout: `context.ts`, `prompt.ts`, `schema.ts`, `providers.ts`, `persist.ts`, `index.ts`, not the `_shared/` split below)
- ❌ `supabase/functions/_shared/extraction/{context,prompt,schema,persist}.ts` — not built; equivalents exist flat inside `extract/` instead (no `_shared/` directory at all)
- ❌ `supabase/functions/_shared/llm/{provider,anthropic,openai}.ts` — not built; a single `extract/providers.ts` covers this instead
- ❌ `supabase/functions/transcribe/index.ts` — not started, still `.gitkeep`
- ❓ Storage: `captures` bucket — not confirmed on the live project; genuine blocker for `transcribe`
- `CareAid/CareAid/Models/ExtractionResponse.swift`, `Artifact.swift`, `Brief.swift`, `Coding.swift` — fixed contract references, do not change
- `supabase/migrations/001_schema.sql` — CHECK constraints source of truth
- `supabase/migrations/002_seed.sql` — test data (recipient `11111111-…`, Tom = circle member `33333333-3333-4333-8333-000000000001`)

## Verification

Steps 2–6 and 8–9 have been run for `extract` against the live demo capture (see STATUS banner) — all passed. Steps 1 and 7 (bucket creation, `transcribe` test) remain outstanding since `transcribe` isn't built.

1. Create the `captures` Storage bucket (see "Storage bucket" above) and confirm with `select id, public from storage.buckets;` before deploying `transcribe` — it will fail every request otherwise. Deploy both functions via `mcp__claude_ai_Supabase__deploy_edge_function` to project `prpuxfpkxdsuxjihkkdt`; set the four secrets above.
2. Insert a fresh test capture via `execute_sql` using CLAUDE.md §9's demo script verbatim as `raw_text` (recipient `11111111-1111-4111-8111-111111111111`, author `22222222-2222-4222-8222-222222222222`, source `text`) — this is the one case where CLAUDE.md fully specifies the expected output, making it the ideal end-to-end test.
3. `curl -X POST {project_url}/functions/v1/extract -d '{"capture_id":"<id>"}'` and confirm: one `medication` timeline_event, a `task` artifact (ring the surgery), a `family_update` to Tom (`to_circle_member_id` matches the seeded UUID), a `question` re night-time freezing, a `calendar_event` for 14 August, non-empty `patterns` ("third missed evening dose"), and **no** `medication_update` (nothing stated a dose changed — this exercises prompt rule 8 against a model that might wrongly infer one from "forgotten her evening Sinemet").
4. Verify persistence directly with `execute_sql`: `select kind,status,payload from artifact where capture_id=...`, `select kind,headline,severity from timeline_event where capture_id=...`, `select processed_at, model_raw->>'provider' from capture where id=...`, `select version,content from brief where recipient_id=... order by version desc limit 1`.
5. **Retry-safety**: call `extract` again with the same `capture_id`; confirm artifact/timeline_event row counts for that `capture_id` are unchanged (not doubled).
6. **Fallback test**: set `LLM_PROVIDER=anthropic` but an invalid `ANTHROPIC_API_KEY`, rerun, confirm `model_raw->>'provider'='openai'` (automatic fallback fired).
7. **`transcribe` test**: upload a short known audio clip to the `captures` Storage bucket via the Storage REST API, `curl` `transcribe` with its `storage_path`, confirm a non-empty transcript roughly matching the clip.
8. Edge cases: `capture_id` with null `raw_text` → 422; nonexistent `capture_id` → 404; missing body → 400.
9. Check `mcp__claude_ai_Supabase__get_logs` (service `edge-function`) after each test for any silent `console.error` not surfaced in the HTTP response.
