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
    sections.push(`ALREADY IN THE DIARY
Do not propose a calendar event that duplicates one of these.
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
