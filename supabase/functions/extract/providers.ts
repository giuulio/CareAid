// One interface, two providers, selected by LLM_PROVIDER. CLAUDE.md §3.
//
// Both are hackathon sponsors and both are implemented deliberately. Switching
// is an env var: `supabase secrets set LLM_PROVIDER=anthropic`.
//
// Keys are read from the environment here and nowhere else. They never reach
// the app bundle (§2, rule 5).

import { EXTRACTION_SCHEMA, type ModelOutput } from "./schema.ts";

export interface Provider {
  readonly name: string;
  readonly model: string;
  complete(system: string, user: string): Promise<{ output: ModelOutput; raw: unknown }>;
}

export function selectProvider(): Provider {
  const choice = (Deno.env.get("LLM_PROVIDER") ?? "openai").toLowerCase();
  switch (choice) {
    case "anthropic":
      return anthropic();
    case "openai":
      return openai();
    default:
      throw new Error(`LLM_PROVIDER must be "openai" or "anthropic", got "${choice}"`);
  }
}

function requireKey(name: string): string {
  const key = Deno.env.get(name);
  if (!key) throw new Error(`${name} is not set. Run: supabase secrets set --env-file supabase/.env`);
  return key;
}

/** Parses the model's JSON, or throws with enough context to debug it. */
function parseOutput(text: string, provider: string): ModelOutput {
  try {
    return JSON.parse(text) as ModelOutput;
  } catch {
    throw new Error(`${provider} returned unparseable JSON: ${text.slice(0, 400)}`);
  }
}

// MARK: - OpenAI

function openai(): Provider {
  // Luna over Sol: the capture screen sits on this call for the length of the
  // pause on stage, and Luna is the faster of the two. The extraction is a
  // structured-output job against an injected context, not a reasoning one.
  const model = Deno.env.get("OPENAI_MODEL") ?? "gpt-5.6-luna";
  return {
    name: "openai",
    model,
    async complete(system, user) {
      const response = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${requireKey("OPENAI_API_KEY")}`,
        },
        body: JSON.stringify({
          model,
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
          response_format: {
            type: "json_schema",
            json_schema: { name: "care_extraction", schema: EXTRACTION_SCHEMA, strict: true },
          },
        }),
      });

      const raw = await response.json();
      if (!response.ok) {
        throw new Error(`OpenAI ${response.status}: ${JSON.stringify(raw).slice(0, 400)}`);
      }
      const text = raw?.choices?.[0]?.message?.content;
      if (typeof text !== "string") {
        throw new Error(`OpenAI returned no content: ${JSON.stringify(raw).slice(0, 400)}`);
      }
      return { output: parseOutput(text, "OpenAI"), raw };
    },
  };
}

// MARK: - Anthropic

function anthropic(): Provider {
  const model = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-opus-5";
  return {
    name: "anthropic",
    model,
    async complete(system, user) {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": requireKey("ANTHROPIC_API_KEY"),
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model,
          max_tokens: 16000,
          system,
          messages: [{ role: "user", content: user }],
          output_config: {
            format: { type: "json_schema", schema: EXTRACTION_SCHEMA },
          },
        }),
      });

      const raw = await response.json();
      if (!response.ok) {
        throw new Error(`Anthropic ${response.status}: ${JSON.stringify(raw).slice(0, 400)}`);
      }
      // Safety classifiers can decline with a 200 — check before reading content.
      if (raw?.stop_reason === "refusal") {
        throw new Error("Anthropic declined this request (stop_reason: refusal).");
      }
      const text = raw?.content?.find((b: { type: string }) => b.type === "text")?.text;
      if (typeof text !== "string") {
        throw new Error(`Anthropic returned no text block: ${JSON.stringify(raw).slice(0, 400)}`);
      }
      return { output: parseOutput(text, "Anthropic"), raw };
    },
  };
}
