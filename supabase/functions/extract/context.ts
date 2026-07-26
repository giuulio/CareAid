// Assembles everything the model needs, server-side. CLAUDE.md §7.
//
// The 90 days of timeline headlines are the expensive part and the whole point:
// pattern detection is impossible without them, and they cost ~700 tokens.

import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export interface Capture {
  id: string;
  recipient_id: string;
  raw_text: string | null;
}

export async function loadCapture(db: SupabaseClient, captureID: string): Promise<Capture> {
  const { data, error } = await db
    .from("capture")
    .select("id, recipient_id, raw_text")
    .eq("id", captureID)
    .single();
  if (error || !data) throw new Error(`No such capture: ${captureID}`);
  return data as Capture;
}

/** What the app tells us when this capture is her correcting an earlier one. */
export interface CorrectionRequest {
  corrects_capture_id: string;
  rejected_artifact_ids?: string[];
}

/**
 * The block that turns a second recording into a correction of the first.
 *
 * Assembled here rather than sent by the app, like every other piece of
 * context (CLAUDE.md §7): the app passes ids, we read the rows. That also means
 * the model sees what each earlier proposal *actually* was, not the app's
 * shortened card copy.
 */
export async function buildCorrection(
  db: SupabaseClient,
  request: CorrectionRequest,
): Promise<string> {
  const [previous, artifacts] = await Promise.all([
    db.from("capture").select("raw_text").eq("id", request.corrects_capture_id).maybeSingle(),
    db.from("artifact")
      .select("id, kind, payload, status")
      .eq("capture_id", request.corrects_capture_id)
      .order("created_at", { ascending: true }),
  ]);

  const rejected = new Set(request.rejected_artifact_ids ?? []);
  const lines = (artifacts.data ?? []).map((a) => {
    const verdict = rejected.has(a.id)
      ? "SHE SAID THIS ONE WAS WRONG"
      : a.status === "approved" || a.status === "sent" || a.status === "done"
      ? "she already approved this — it has happened"
      : "she has not decided on this one";
    return `- ${a.kind}: ${JSON.stringify(a.payload)} → ${verdict}`;
  });

  return `SHE IS CORRECTING AN EARLIER NOTE

A few moments ago she said:
"""
${previous.data?.raw_text ?? "(the earlier note could not be read)"}
"""

That produced these proposals:
${lines.length ? lines.join("\n") : "- (none)"}

The recording below is her saying it again because something above was wrong.
Treat the two notes as one story, with the new one authoritative wherever they
disagree.

- The timeline events from the earlier note are ALREADY RECORDED. Do not emit
  them again. Emit an event only for something she has not already had recorded,
  or where her correction changes what happened.
- Do not re-propose anything she already approved. It is done.
- Do not re-propose what she rejected unless her new words plainly ask for it.
- Do re-propose anything she had not decided on that still stands, so she does
  not lose it — the earlier proposals are being cleared from her screen.
- If her correction is about the wording or a detail of a proposal, emit the
  fixed version, not a note about the fix.`;
}

export async function buildContext(db: SupabaseClient, capture: Capture): Promise<string> {
  const recipientID = capture.recipient_id;
  const now = new Date();
  const ninetyDaysAgo = new Date(now.getTime() - 90 * 86_400_000).toISOString();

  const [recipient, medications, circle, timeline, upcoming, brief] = await Promise.all([
    db.from("recipient").select("*").eq("id", recipientID).single(),
    db.from("medication").select("*").eq("recipient_id", recipientID).eq("active", true),
    db.from("circle_member").select("*").eq("recipient_id", recipientID),
    db.from("timeline_event")
      .select("id, kind, occurred_at, headline, severity")
      .eq("recipient_id", recipientID)
      .gte("occurred_at", ninetyDaysAgo)
      .lte("occurred_at", now.toISOString())
      .order("occurred_at", { ascending: false })
      .limit(200),
    db.from("timeline_event")
      .select("kind, occurred_at, headline")
      .eq("recipient_id", recipientID)
      .gt("occurred_at", now.toISOString())
      .order("occurred_at", { ascending: true })
      .limit(5),
    db.from("brief")
      .select("content, version")
      .eq("recipient_id", recipientID)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);

  const r = recipient.data;
  const london = now.toLocaleString("en-GB", { timeZone: "Europe/London", dateStyle: "full", timeStyle: "short" });

  const sections: string[] = [];

  sections.push(`CURRENT DATETIME
${london} (Europe/London). In UTC that is ${now.toISOString()}.
Resolve every relative time against this.`);

  if (r) {
    sections.push(`WHO SHE IS CARING FOR
${r.display_name}${r.legal_name ? ` (${r.legal_name})` : ""}${r.year_of_birth ? `, born ${r.year_of_birth}` : ""}
Conditions: ${(r.conditions ?? []).join("; ") || "none recorded"}
Allergies: ${(r.allergies ?? []).join("; ") || "none recorded"}
GP: ${r.gp_practice ?? "not recorded"}`);
  }

  if (medications.data?.length) {
    const lines = medications.data.map((m) =>
      `- ${m.name}${m.dose ? ` ${m.dose}` : ""} — ${m.schedule ?? "no schedule recorded"}` +
      `${m.scheduled_times?.length ? ` (${m.scheduled_times.join(", ")})` : ""} [id: ${m.id}]`
    );
    sections.push(`ACTIVE MEDICATIONS
Use these ids for medication_update. Match on name, including brand names she may use.
${lines.join("\n")}`);
  }

  if (circle.data?.length) {
    const lines = circle.data.map((c) =>
      `- ${c.name}${c.relation ? `, ${c.relation}` : ""} — reachable by ${c.channel} [id: ${c.id}]`
    );
    sections.push(`HER CIRCLE
Resolve any name she mentions to one of these ids.
${lines.join("\n")}`);
  }

  if (upcoming.data?.length) {
    const lines = upcoming.data.map((e) => `- ${e.occurred_at} — ${e.headline}`);
    sections.push(`APPOINTMENTS ALREADY RECORDED
These are CareAid's own records. They are NOT in Sarah's phone calendar.

So if she mentions one of these, still propose a calendar event — that is how it
reaches her actual diary. Use the date and time recorded here rather than
resolving hers, since she is often vague ("the 14th") and this is authoritative.
Only skip it if she is plainly just referring to the appointment in passing and
not asking to be reminded of it.
${lines.join("\n")}`);
  }

  if (brief.data?.content) {
    sections.push(`CURRENT BRIEF (version ${brief.data.version})
${JSON.stringify(brief.data.content, null, 2)}`);
  }

  if (timeline.data?.length) {
    const lines = timeline.data.map((e) =>
      `- [${e.id}] ${e.occurred_at.slice(0, 10)} (${e.kind}, severity ${e.severity}) ${e.headline}`
    );
    sections.push(`THE LAST 90 DAYS, NEWEST FIRST
This is what lets you spot a pattern. Cite these ids in evidence_event_ids.
${lines.join("\n")}`);
  }

  return sections.join("\n\n");
}
