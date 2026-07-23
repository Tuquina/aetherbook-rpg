// Gemini-backed narrator (CLAUDE.md §9, GDD §7.3): the principal narrator.
// Uses Gemini's native structured output (responseSchema) to force the
// contract shape, which drastically cuts down on broken JSON. If the first
// reply still fails to parse, one repair retry is attempted before giving up
// (CLAUDE.md §5.2).

import type { NarratorAdapter, NarratorRequest, NarratorResponse } from "./types.ts";
import { NarratorProviderError } from "./types.ts";
import { NarratorParseError, parseNarratorJson } from "./narrator_json_parser.ts";
import { buildSystemPrompt, buildUserPrompt } from "./prompt_builder.ts";

/** The JSON schema handed to Gemini's `responseSchema` (subset of OpenAPI). */
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    narration: { type: "STRING" },
    suggested_choices: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          id: { type: "STRING" },
          label: { type: "STRING" },
          intent: { type: "STRING" },
          expected_check: {
            type: "OBJECT",
            properties: {
              attribute: { type: "STRING" },
              difficulty_id: { type: "STRING" },
            },
            required: ["attribute"],
          },
        },
        required: ["id", "label"],
      },
    },
    proposed_state_deltas: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          type: {
            type: "STRING",
            enum: ["flag", "exp", "resource", "meter", "relationship"],
          },
          key: { type: "STRING" },
          value: { anyOf: [{ type: "BOOLEAN" }, { type: "NUMBER" }] },
          operation: { type: "STRING", enum: ["increment"] },
          reason: { type: "STRING" },
        },
        required: ["type", "key", "value", "operation", "reason"],
      },
    },
    image_prompt: { type: "STRING" },
    tone: { type: "STRING" },
    memory_facts: { type: "ARRAY", items: { type: "STRING" } },
    node_status: { type: "STRING", enum: ["active", "ready_to_exit"] },
  },
  required: [
    "narration",
    "suggested_choices",
    "proposed_state_deltas",
    "image_prompt",
    "tone",
    "memory_facts",
    "node_status",
  ],
};

export interface GeminiNarratorAdapterOptions {
  apiKey: string;
  model?: string;
  /** Injectable for tests; defaults to the global `fetch`. */
  fetchImpl?: typeof fetch;
}

export class GeminiNarratorAdapter implements NarratorAdapter {
  readonly name = "gemini";

  private readonly apiKey: string;
  private readonly model: string;
  private readonly fetchImpl: typeof fetch;

  constructor(options: GeminiNarratorAdapterOptions) {
    this.apiKey = options.apiKey;
    this.model = options.model ?? "gemini-flash-latest";
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async narrate(request: NarratorRequest): Promise<NarratorResponse> {
    const systemPrompt = buildSystemPrompt(request);
    const userPrompt = buildUserPrompt(request);

    const raw = await this.callGemini(systemPrompt, userPrompt);

    try {
      return parseNarratorJson(raw);
    } catch (e) {
      if (!(e instanceof NarratorParseError)) throw e;
      // Repair retry: ask explicitly for valid JSON (CLAUDE.md §5.2).
      const repaired = await this.callGemini(
        systemPrompt,
        `${userPrompt}\n\nTu respuesta anterior no era JSON válido. ` +
          `Devolvé JSON válido que cumpla el schema exactamente.`,
      );
      try {
        return parseNarratorJson(repaired);
      } catch (e2) {
        throw new NarratorProviderError(
          `Gemini returned unparseable JSON twice: ${(e2 as Error).message}`,
          false,
          e2,
        );
      }
    }
  }

  private async callGemini(
    systemPrompt: string,
    userPrompt: string,
  ): Promise<string> {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/` +
      `${this.model}:generateContent?key=${this.apiKey}`;

    let response: Response;
    try {
      response = await this.fetchImpl(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents: [{ role: "user", parts: [{ text: userPrompt }] }],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema: RESPONSE_SCHEMA,
          },
        }),
      });
    } catch (e) {
      throw new NarratorProviderError(`Gemini request failed: ${e}`, false, e);
    }

    if (!response.ok) {
      const isRateLimit = response.status === 429;
      const body = await safeText(response);
      throw new NarratorProviderError(
        `Gemini responded ${response.status}: ${body}`,
        isRateLimit,
      );
    }

    const json = await response.json();
    const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") {
      throw new NarratorProviderError(
        "Gemini response missing candidates[0].content.parts[0].text",
        false,
        json,
      );
    }
    return text;
  }
}

async function safeText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return "<unreadable body>";
  }
}
