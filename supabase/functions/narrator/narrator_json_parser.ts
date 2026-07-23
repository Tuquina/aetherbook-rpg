// Tolerant parser for a narrator provider's raw text output (CLAUDE.md §5):
// strips markdown fences and any surrounding prose, then validates the JSON
// contract. Every provider adapter (Gemini, Groq) routes its raw response
// through this, so the same parsing rules apply everywhere, including the
// retry-of-repair path.

import type { NarratorResponse, StateDeltaWire } from "./types.ts";

export class NarratorParseError extends Error {
  constructor(message: string, readonly rawOutput: string) {
    super(message);
    this.name = "NarratorParseError";
  }
}

export function parseNarratorJson(raw: string): NarratorResponse {
  const cleaned = extractJsonObject(raw);

  let decoded: unknown;
  try {
    decoded = JSON.parse(cleaned);
  } catch (e) {
    throw new NarratorParseError(
      `invalid JSON: ${(e as Error).message}`,
      raw,
    );
  }

  if (typeof decoded !== "object" || decoded === null) {
    throw new NarratorParseError("expected a JSON object", raw);
  }

  const obj = decoded as Record<string, unknown>;
  if (typeof obj.narration !== "string") {
    throw new NarratorParseError('missing "narration" string', raw);
  }

  return {
    narration: obj.narration,
    suggested_choices: stringList(obj.suggested_choices),
    state_deltas: deltas(obj.state_deltas),
    image_prompt: typeof obj.image_prompt === "string" ? obj.image_prompt : "",
    tone: typeof obj.tone === "string" ? obj.tone : "",
  };
}

/** Removes ```json fences / preamble and keeps the outermost `{...}` object. */
function extractJsonObject(raw: string): string {
  let text = raw.trim();

  text = text.replace(/^```[a-zA-Z]*\s*/, "");
  if (text.endsWith("```")) {
    text = text.slice(0, -3);
  }

  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start !== -1 && end !== -1 && end > start) {
    text = text.slice(start, end + 1);
  }

  return text.trim();
}

function stringList(value: unknown): string[] {
  if (Array.isArray(value)) {
    return value.filter((v): v is string => typeof v === "string");
  }
  return [];
}

function deltas(value: unknown): StateDeltaWire[] {
  if (!Array.isArray(value)) return [];
  const result: StateDeltaWire[] = [];
  for (const item of value) {
    if (item && typeof item === "object") {
      const rec = item as Record<string, unknown>;
      if (typeof rec.type === "string" && typeof rec.key === "string") {
        result.push({ type: rec.type, key: rec.key, value: rec.value });
      }
    }
  }
  return result;
}
