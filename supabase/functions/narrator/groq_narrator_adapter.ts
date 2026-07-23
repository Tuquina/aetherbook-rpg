// Groq-backed narrator (CLAUDE.md §9, GDD §7.3): the fast fallback. Groq's
// API is OpenAI-compatible; it supports JSON mode (`response_format:
// json_object`) but not a full schema like Gemini's structured output, so we
// lean harder on the tolerant parser and the repair retry here.

import type { NarratorAdapter, NarratorRequest, NarratorResponse } from "./types.ts";
import { NarratorProviderError } from "./types.ts";
import { NarratorParseError, parseNarratorJson } from "./narrator_json_parser.ts";
import { buildSystemPrompt, buildUserPrompt } from "./prompt_builder.ts";

export interface GroqNarratorAdapterOptions {
  apiKey: string;
  model?: string;
  /** Injectable for tests; defaults to the global `fetch`. */
  fetchImpl?: typeof fetch;
}

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

export class GroqNarratorAdapter implements NarratorAdapter {
  readonly name = "groq";

  private readonly apiKey: string;
  private readonly model: string;
  private readonly fetchImpl: typeof fetch;

  constructor(options: GroqNarratorAdapterOptions) {
    this.apiKey = options.apiKey;
    // Free-tier model availability shifts often (GDD §7.3) — override via env.
    this.model = options.model ?? "llama-3.3-70b-versatile";
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async narrate(request: NarratorRequest): Promise<NarratorResponse> {
    const systemPrompt = buildSystemPrompt(request);
    const userPrompt = buildUserPrompt(request);

    const raw = await this.callGroq(systemPrompt, userPrompt);

    try {
      return parseNarratorJson(raw);
    } catch (e) {
      if (!(e instanceof NarratorParseError)) throw e;
      const repaired = await this.callGroq(
        systemPrompt,
        `${userPrompt}\n\nTu respuesta anterior no era JSON válido. ` +
          `Devolvé SOLO JSON válido, sin texto extra.`,
      );
      try {
        return parseNarratorJson(repaired);
      } catch (e2) {
        throw new NarratorProviderError(
          `Groq returned unparseable JSON twice: ${(e2 as Error).message}`,
          false,
          e2,
        );
      }
    }
  }

  private async callGroq(
    systemPrompt: string,
    userPrompt: string,
  ): Promise<string> {
    let response: Response;
    try {
      response = await this.fetchImpl(GROQ_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          model: this.model,
          response_format: { type: "json_object" },
          messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: userPrompt },
          ],
        }),
      });
    } catch (e) {
      throw new NarratorProviderError(`Groq request failed: ${e}`, false, e);
    }

    if (!response.ok) {
      const isRateLimit = response.status === 429;
      const body = await safeText(response);
      throw new NarratorProviderError(
        `Groq responded ${response.status}: ${body}`,
        isRateLimit,
      );
    }

    const json = await response.json();
    const text = json?.choices?.[0]?.message?.content;
    if (typeof text !== "string") {
      throw new NarratorProviderError(
        "Groq response missing choices[0].message.content",
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
