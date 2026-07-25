// The JSON schema the model must fill in, plus the TypeScript shape it maps to.
//
// One schema, both providers. Written to OpenAI's strict-mode rules, which are
// the stricter of the two:
//   - every property listed in `required`
//   - `additionalProperties: false` on every object
//   - optionals expressed as a nullable type union, never by omission
//   - no `anyOf` — which is why artifacts arrive as per-kind arrays rather than
//     one array of six payload shapes (CLAUDE.md §7)

const nullableString = { type: ["string", "null"] } as const;
const nullableNumber = { type: ["number", "null"] } as const;

/** Wraps a payload with the model's confidence in it. */
function artifactArray(payload: Record<string, unknown>, required: string[]) {
  return {
    type: "array",
    items: {
      type: "object",
      properties: {
        confidence: nullableNumber,
        payload: {
          type: "object",
          properties: payload,
          required,
          additionalProperties: false,
        },
      },
      required: ["confidence", "payload"],
      additionalProperties: false,
    },
  };
}

export const EXTRACTION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "events",
    "tasks",
    "calendar_events",
    "family_updates",
    "questions",
    "timers",
    "medication_updates",
    "brief_patch",
    "patterns",
    "flags",
  ],
  properties: {
    events: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["kind", "occurred_at", "headline", "detail", "severity", "tags", "confidence"],
        properties: {
          kind: {
            type: "string",
            enum: ["symptom", "medication", "incident", "appointment", "mood", "care_task", "admin"],
          },
          occurred_at: { type: "string", description: "ISO 8601 UTC" },
          headline: { type: "string", description: "60 characters or fewer, plain English" },
          detail: nullableString,
          severity: { type: "integer", enum: [0, 1, 2, 3] },
          tags: { type: "array", items: { type: "string" } },
          confidence: nullableNumber,
        },
      },
    },

    tasks: artifactArray(
      { title: { type: "string" }, due_at: nullableString, why: { type: "string" } },
      ["title", "due_at", "why"],
    ),

    calendar_events: artifactArray(
      {
        title: { type: "string" },
        starts_at: { type: "string" },
        ends_at: nullableString,
        location: nullableString,
        notes: nullableString,
        reminders_min: { type: "array", items: { type: "integer" } },
      },
      ["title", "starts_at", "ends_at", "location", "notes", "reminders_min"],
    ),

    family_updates: artifactArray(
      {
        to_circle_member_id: nullableString,
        to_name: { type: "string" },
        channel: { type: "string", enum: ["whatsapp", "sms", "email"] },
        draft_text: { type: "string", description: "Three sentences maximum" },
      },
      ["to_circle_member_id", "to_name", "channel", "draft_text"],
    ),

    questions: artifactArray(
      {
        question: { type: "string" },
        for_specialty: nullableString,
        priority: { type: ["integer", "null"] },
      },
      ["question", "for_specialty", "priority"],
    ),

    timers: artifactArray(
      { label: { type: "string" }, fire_at: { type: "string" }, repeat: nullableString },
      ["label", "fire_at", "repeat"],
    ),

    medication_updates: artifactArray(
      {
        medication_id: { type: "string" },
        medication_name: { type: "string" },
        field: { type: "string", enum: ["dose", "schedule", "active", "quantity_remaining"] },
        from: nullableString,
        to: { type: "string" },
        why: { type: "string", description: "Attribution, never rationale" },
      },
      ["medication_id", "medication_name", "field", "from", "to", "why"],
    ),

    brief_patch: {
      type: "object",
      additionalProperties: false,
      required: ["one_liner", "add_concerns", "resolve_concerns", "medication_changes"],
      properties: {
        one_liner: nullableString,
        add_concerns: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["text", "since", "trend"],
            properties: {
              text: { type: "string" },
              since: nullableString,
              trend: { type: ["string", "null"], enum: ["improving", "stable", "worsening", null] },
            },
          },
        },
        resolve_concerns: { type: "array", items: { type: "string" } },
        medication_changes: { type: "array", items: { type: "string" } },
      },
    },

    patterns: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["observation", "evidence_event_ids"],
        properties: {
          observation: { type: "string" },
          evidence_event_ids: { type: "array", items: { type: "string" } },
        },
      },
    },

    flags: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["type", "text", "ask"],
        properties: {
          type: { type: "string" },
          text: nullableString,
          ask: { type: "string" },
        },
      },
    },
  },
} as const;

// MARK: - What the model gives us back

export interface ModelEvent {
  kind: string;
  occurred_at: string;
  headline: string;
  detail: string | null;
  severity: number;
  tags: string[];
  confidence: number | null;
}

export interface ModelArtifact<P> {
  confidence: number | null;
  payload: P;
}

export interface ModelOutput {
  events: ModelEvent[];
  tasks: ModelArtifact<Record<string, unknown>>[];
  calendar_events: ModelArtifact<Record<string, unknown>>[];
  family_updates: ModelArtifact<Record<string, unknown>>[];
  questions: ModelArtifact<Record<string, unknown>>[];
  timers: ModelArtifact<Record<string, unknown>>[];
  medication_updates: ModelArtifact<Record<string, unknown>>[];
  brief_patch: {
    one_liner: string | null;
    add_concerns: { text: string; since: string | null; trend: string | null }[];
    resolve_concerns: string[];
    medication_changes: string[];
  };
  patterns: { observation: string; evidence_event_ids: string[] }[];
  flags: { type: string; text: string | null; ask: string }[];
}

/** Maps each per-kind array back to the `artifact.kind` it becomes. */
export const ARTIFACT_KINDS: { field: keyof ModelOutput; kind: string }[] = [
  { field: "tasks", kind: "task" },
  { field: "calendar_events", kind: "calendar_event" },
  { field: "family_updates", kind: "family_update" },
  { field: "questions", kind: "question" },
  { field: "timers", kind: "timer" },
  { field: "medication_updates", kind: "medication_update" },
];
