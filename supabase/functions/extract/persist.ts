// The Edge Function owns every extraction write (CLAUDE.md §7).
//
// Idempotent by construction: rows are keyed on capture_id and deleted before
// reinsert, so a retry after a network drop replaces rather than duplicates.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { ARTIFACT_KINDS, type ModelOutput } from "./schema.ts";
import type { Capture } from "./context.ts";

export interface ExtractionResponse {
  capture_id: string;
  events: unknown[];
  artifacts: unknown[];
  patterns: unknown[];
  flags: unknown[];
  brief: unknown | null;
}

export async function persist(
  db: SupabaseClient,
  capture: Capture,
  output: ModelOutput,
  raw: unknown,
): Promise<ExtractionResponse> {
  // Replace anything a previous attempt left behind.
  await db.from("timeline_event").delete().eq("capture_id", capture.id);
  await db.from("artifact").delete().eq("capture_id", capture.id);

  const events = await insertEvents(db, capture, output);
  const artifacts = await insertArtifacts(db, capture, output);
  const brief = await applyBriefPatch(db, capture, output);

  await db
    .from("capture")
    .update({ processed_at: new Date().toISOString(), model_raw: raw })
    .eq("id", capture.id);

  return {
    capture_id: capture.id,
    events,
    artifacts,
    patterns: output.patterns ?? [],
    flags: output.flags ?? [],
    brief,
  };
}

async function insertEvents(db: SupabaseClient, capture: Capture, output: ModelOutput) {
  if (!output.events?.length) return [];
  const rows = output.events.map((e) => ({
    recipient_id: capture.recipient_id,
    capture_id: capture.id,
    kind: e.kind,
    occurred_at: e.occurred_at,
    headline: e.headline.slice(0, 60), // §7 rule 5, enforced not just requested
    detail: e.detail,
    severity: e.severity ?? 0,
    tags: e.tags ?? [],
    confidence: e.confidence,
  }));
  const { data, error } = await db.from("timeline_event").insert(rows).select();
  if (error) throw new Error(`timeline_event insert failed: ${error.message}`);
  return data ?? [];
}

async function insertArtifacts(db: SupabaseClient, capture: Capture, output: ModelOutput) {
  // Flatten the per-kind arrays back into one artifact table (CLAUDE.md §7).
  const rows = ARTIFACT_KINDS.flatMap(({ field, kind }) => {
    const entries = (output[field] ?? []) as { confidence: number | null; payload: unknown }[];
    return entries.map((entry) => ({
      recipient_id: capture.recipient_id,
      capture_id: capture.id,
      kind,
      payload: entry.payload,
      status: "proposed", // §2 rule 3 — nothing acts without a tap
      confidence: entry.confidence,
    }));
  });

  if (!rows.length) return [];
  const { data, error } = await db.from("artifact").insert(rows).select();
  if (error) throw new Error(`artifact insert failed: ${error.message}`);
  return data ?? [];
}

/**
 * Briefs are versioned, never overwritten — so a patch reads the current
 * version, applies the delta, and writes a new one.
 */
async function applyBriefPatch(db: SupabaseClient, capture: Capture, output: ModelOutput) {
  const patch = output.brief_patch;
  const hasChange = patch &&
    (patch.one_liner || patch.add_concerns?.length ||
      patch.resolve_concerns?.length || patch.medication_changes?.length);
  if (!hasChange) return null;

  const { data: current } = await db
    .from("brief")
    .select("content, version")
    .eq("recipient_id", capture.recipient_id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  const content = structuredClone(current?.content ?? {
    one_liner: "",
    current_concerns: [],
    medications: [],
    recent_changes: [],
    open_questions: [],
    whats_working: [],
  }) as Record<string, unknown>;

  if (patch.one_liner) content.one_liner = patch.one_liner;

  const resolved = new Set(patch.resolve_concerns ?? []);
  const concerns = ((content.current_concerns ?? []) as { text: string }[])
    .filter((c) => !resolved.has(c.text));
  for (const added of patch.add_concerns ?? []) {
    if (!concerns.some((c) => c.text === added.text)) concerns.push(added);
  }
  content.current_concerns = concerns;

  if (patch.medication_changes?.length) {
    content.recent_changes = [
      ...patch.medication_changes,
      ...((content.recent_changes ?? []) as string[]),
    ].slice(0, 10);
  }

  const { data, error } = await db
    .from("brief")
    .insert({
      recipient_id: capture.recipient_id,
      version: (current?.version ?? 0) + 1,
      content,
      source_capture_id: capture.id,
    })
    .select()
    .single();
  if (error) throw new Error(`brief insert failed: ${error.message}`);
  return data;
}
