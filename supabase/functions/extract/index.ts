// POST /functions/v1/extract  { "capture_id": "<uuid>" }
//
// One LLM call per capture, not a chain (CLAUDE.md §7). Context is assembled
// here and injected; the model gets no tools and no database access.
//
// The function owns every extraction write and returns the persisted rows with
// their ids. The app decodes and renders — it never inserts.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { loadCapture, buildContext, buildCorrection } from "./context.ts";
import { SYSTEM_PROMPT, userPrompt } from "./prompt.ts";
import { selectProvider } from "./providers.ts";
import { persist } from "./persist.ts";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  const started = Date.now();
  let captureID: string | undefined;

  try {
    const body = await req.json().catch(() => ({}));
    captureID = body?.capture_id;
    if (!captureID) return json({ error: "capture_id is required" }, 400);

    // Service role: RLS is off for the demo, but this keeps the function
    // working unchanged if policies are ever added.
    const db = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const capture = await loadCapture(db, captureID);
    if (!capture.raw_text?.trim()) {
      return json({ error: "capture has no text to extract" }, 400);
    }

    // Optional: this capture is her saying it again because a card was wrong.
    const correction = body?.corrects_capture_id
      ? await buildCorrection(db, {
        corrects_capture_id: body.corrects_capture_id,
        rejected_artifact_ids: body.rejected_artifact_ids,
      })
      : undefined;

    const context = [await buildContext(db, capture), correction]
      .filter(Boolean)
      .join("\n\n");
    const provider = selectProvider();

    console.log(
      `extract ${captureID} via ${provider.name}/${provider.model}, ` +
      `context ${context.length} chars`,
    );

    const { output, raw } = await provider.complete(
      SYSTEM_PROMPT,
      userPrompt(context, capture.raw_text),
    );

    const result = await persist(db, capture, output, raw);

    console.log(
      `extract ${captureID} done in ${Date.now() - started}ms: ` +
      `${result.events.length} events, ${result.artifacts.length} artifacts, ` +
      `${result.patterns.length} patterns, ${result.flags.length} flags`,
    );

    return json(result);
  } catch (error) {
    // The capture row survives regardless — the raw note is never lost
    // (CLAUDE.md §8). Surface the reason so the app can show it.
    const message = error instanceof Error ? error.message : String(error);
    console.error(`extract ${captureID ?? "?"} failed after ${Date.now() - started}ms: ${message}`);
    return json({ error: message }, 500);
  }
});
