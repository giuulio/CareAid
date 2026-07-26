// POST /functions/v1/transcribe
//
// Body is the raw audio — no JSON envelope, no base64, no Storage round trip.
// `content-type` carries the format (audio/m4a today) and the response is
// `{ "transcript": "..." }`.
//
// Why not the signed-URL-from-Storage flow EDGE_FUNCTIONS_PLAN.md sketched:
// that needs a bucket, an upload, a signed URL and a fetch before the first
// byte reaches a transcriber — four things to fail on stage, in the one part of
// the demo where Sarah is stood there having just finished talking. The audio
// is a few hundred kilobytes of AAC; posting it straight here is one hop.
// Storage stays worth having for photo capture, which does need a durable URL.
//
// Keys are read from the environment here and nowhere else. They never reach
// the app bundle (CLAUDE.md §2, rule 5).

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

/** Anything bigger than this is not a caregiver's note. */
const MAX_BYTES = 20 * 1024 * 1024;

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const started = Date.now();
  try {
    const audio = await req.arrayBuffer();
    if (audio.byteLength === 0) return json({ error: "no audio in the request body" }, 400);
    if (audio.byteLength > MAX_BYTES) return json({ error: "audio too large" }, 413);

    const contentType = req.headers.get("content-type") ?? "audio/m4a";
    const provider = (Deno.env.get("STT_PROVIDER") ?? "openai").toLowerCase();
    const vocabulary = await careVocabulary();

    console.log(
      `transcribe ${audio.byteLength} bytes of ${contentType} via ${provider}`,
    );

    const transcript = provider === "elevenlabs"
      ? await elevenLabs(audio, contentType)
      : await openai(audio, contentType, vocabulary);

    // An empty transcript is not an error — she may have said nothing, and the
    // app decides what to do about that (CLAUDE.md §8: never lose input).
    console.log(`transcribe done in ${Date.now() - started}ms, ${transcript.length} chars`);
    return json({ transcript });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`transcribe failed after ${Date.now() - started}ms: ${message}`);
    return json({ error: message }, 502);
  }
});

function requireKey(name: string): string {
  const key = Deno.env.get(name);
  if (!key) throw new Error(`${name} is not set. Run: supabase secrets set --env-file supabase/.env`);
  return key;
}

/**
 * Her own record, as a vocabulary hint.
 *
 * A general recogniser hears "co-careldopa" as "cocaine el dopa" and "Okafor"
 * as "okay for". Both transcribers take a hint, and the honest source for one
 * is the list of medicines and people already in *her* record — not a wishlist
 * of words we want to hear. Nothing is invented: if it isn't in the database it
 * isn't in the hint.
 */
async function careVocabulary(): Promise<string> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return "";

  try {
    const db: SupabaseClient = createClient(url, serviceKey);
    const [medications, circle, recipients, appointments] = await Promise.all([
      db.from("medication").select("name").eq("active", true),
      db.from("circle_member").select("name"),
      db.from("recipient").select("legal_name, conditions, gp_practice"),
      // Clinicians live in headlines rather than a table of their own, and a
      // recogniser hears "Okafor" as "okay for" without the hint.
      db.from("timeline_event").select("headline")
        .eq("kind", "appointment").order("occurred_at", { ascending: false }).limit(20),
    ]);

    const words = [
      ...(medications.data ?? []).map((row) => row.name),
      ...(circle.data ?? []).map((row) => row.name),
      ...(recipients.data ?? []).flatMap((row) => [
        row.legal_name,
        row.gp_practice,
        ...(row.conditions ?? []),
      ]),
      ...(appointments.data ?? []).map((row) => row.headline),
    ].filter(Boolean);

    if (words.length === 0) return "";
    return `Names, medicines and conditions that may come up: ${words.join(", ")}.`;
  } catch (error) {
    // A hint is a nicety. Losing it must never cost the transcript.
    console.error(`vocabulary lookup failed, carrying on without it: ${error}`);
    return "";
  }
}

// MARK: - OpenAI

async function openai(audio: ArrayBuffer, contentType: string, hint: string): Promise<string> {
  const model = Deno.env.get("OPENAI_TRANSCRIBE_MODEL") ?? "gpt-4o-transcribe";

  const form = new FormData();
  form.append("file", new Blob([audio], { type: contentType }), filename(contentType));
  form.append("model", model);
  form.append("language", "en");
  form.append("response_format", "json");
  if (hint) form.append("prompt", hint);

  const response = await fetch("https://api.openai.com/v1/audio/transcriptions", {
    method: "POST",
    headers: { authorization: `Bearer ${requireKey("OPENAI_API_KEY")}` },
    body: form,
  });

  const raw = await response.json();
  if (!response.ok) {
    throw new Error(`OpenAI ${response.status}: ${JSON.stringify(raw).slice(0, 400)}`);
  }
  return typeof raw?.text === "string" ? raw.text.trim() : "";
}

// MARK: - ElevenLabs

/**
 * Scribe, per CLAUDE.md §3. Unused until ELEVENLABS_API_KEY exists — flip it on
 * with `supabase secrets set STT_PROVIDER=elevenlabs`, no code change.
 */
async function elevenLabs(audio: ArrayBuffer, contentType: string): Promise<string> {
  const form = new FormData();
  form.append("file", new Blob([audio], { type: contentType }), filename(contentType));
  form.append("model_id", Deno.env.get("ELEVENLABS_MODEL") ?? "scribe_v1");
  form.append("language_code", "eng");

  const response = await fetch("https://api.elevenlabs.io/v1/speech-to-text", {
    method: "POST",
    headers: { "xi-api-key": requireKey("ELEVENLABS_API_KEY") },
    body: form,
  });

  const raw = await response.json();
  if (!response.ok) {
    throw new Error(`ElevenLabs ${response.status}: ${JSON.stringify(raw).slice(0, 400)}`);
  }
  return typeof raw?.text === "string" ? raw.text.trim() : "";
}

/** Both APIs pick their decoder off the extension, not the MIME type. */
function filename(contentType: string): string {
  const extension = contentType.includes("wav")
    ? "wav"
    : contentType.includes("mp4") || contentType.includes("m4a")
    ? "m4a"
    : contentType.includes("caf")
    ? "caf"
    : "m4a";
  return `capture.${extension}`;
}
