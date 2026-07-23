// Summarizes recent turns into a ~150-word digest using Groq (CLAUDE.md §6,
// GDD §5.3: "podés usar Groq, que es rapidísimo, para comprimir 'qué pasó'").
// Plain text output — no structured-output schema needed here, unlike the
// narrator contract.

import type { DigestRequest } from "./types.ts";

export class SummarizerError extends Error {
  constructor(message: string, readonly isRateLimit: boolean = false) {
    super(message);
    this.name = "SummarizerError";
  }
}

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";

const SYSTEM_PROMPT =
  `Resumís lo que pasó en una partida de rol narrativo, en español, en un ` +
  `párrafo de alrededor de 150 palabras. Si te paso un diario previo, ` +
  `continualo incorporando los turnos nuevos en vez de repetir lo mismo — ` +
  `es la memoria de mediano plazo del jugador, tiene que quedar coherente y ` +
  `compacta. Devolvé SOLO el texto del resumen, sin JSON, sin markdown, sin ` +
  `preámbulo.`;

export interface GroqSummarizerOptions {
  apiKey: string;
  model?: string;
  fetchImpl?: typeof fetch;
}

export class GroqSummarizer {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly fetchImpl: typeof fetch;

  constructor(options: GroqSummarizerOptions) {
    this.apiKey = options.apiKey;
    this.model = options.model ?? "llama-3.3-70b-versatile";
    this.fetchImpl = options.fetchImpl ?? fetch;
  }

  async summarize(request: DigestRequest): Promise<string> {
    const userPrompt = this.buildUserPrompt(request);

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
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: userPrompt },
          ],
        }),
      });
    } catch (e) {
      throw new SummarizerError(`Groq request failed: ${e}`, false);
    }

    if (!response.ok) {
      const isRateLimit = response.status === 429;
      const body = await safeText(response);
      throw new SummarizerError(
        `Groq responded ${response.status}: ${body}`,
        isRateLimit,
      );
    }

    const json = await response.json();
    const text = json?.choices?.[0]?.message?.content;
    if (typeof text !== "string" || text.trim().length === 0) {
      throw new SummarizerError(
        "Groq response missing choices[0].message.content",
      );
    }
    return text.trim();
  }

  private buildUserPrompt(request: DigestRequest): string {
    const parts: string[] = [];

    if (request.previousDigest && request.previousDigest.trim().length > 0) {
      parts.push(`Diario previo:\n${request.previousDigest}`);
    }

    const turnsText = request.turnsToSummarize
      .map((t) => `- Acción: ${t.playerAction || "(inicio)"}\n  Narración: ${t.narration}`)
      .join("\n");
    parts.push(`Turnos nuevos a incorporar:\n${turnsText}`);

    return parts.join("\n\n");
  }
}

async function safeText(response: Response): Promise<string> {
  try {
    return await response.text();
  } catch {
    return "<unreadable body>";
  }
}
