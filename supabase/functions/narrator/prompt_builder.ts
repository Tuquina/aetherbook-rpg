// Builds the layered prompt described in CLAUDE.md §5.1: world system prompt,
// compressed state, immediate context, the already-resolved action, and the
// output-format instruction. Shared by every provider adapter so the prompt
// shape never drifts between Gemini and Groq.

import type { NarratorRequest } from "./types.ts";

export const OUTPUT_INSTRUCTION =
  `Devolvé SOLO un objeto JSON válido con esta forma exacta, sin markdown, ` +
  `sin backticks, sin preámbulo ni texto fuera del JSON:\n` +
  `{"narration": string, "suggested_choices": string[], ` +
  `"state_deltas": [{"type": "flag"|"exp"|"resource", "key": string, ` +
  `"value": boolean|number}], "image_prompt": string, "tone": string}`;

export function buildSystemPrompt(request: NarratorRequest): string {
  return [request.world.systemPrompt, OUTPUT_INSTRUCTION]
    .filter((s) => s.trim().length > 0)
    .join("\n\n");
}

export function buildUserPrompt(request: NarratorRequest): string {
  const parts: string[] = [];

  const c = request.character;
  parts.push(
    `Estado del personaje: ${c.name}, nivel ${c.level}, exp ${c.exp}. ` +
      `Atributos: ${JSON.stringify(c.attributes)}. ` +
      `Recursos: ${JSON.stringify(c.resources)}.` +
      (c.flags && Object.keys(c.flags).length > 0
        ? ` Flags activos: ${JSON.stringify(c.flags)}.`
        : ""),
  );

  if (request.memoryDigest && request.memoryDigest.trim().length > 0) {
    parts.push(`Diario de la historia hasta ahora:\n${request.memoryDigest}`);
  }

  if (request.recentTurns && request.recentTurns.length > 0) {
    parts.push(
      `Contexto reciente:\n${request.recentTurns.map((t) => `- ${t}`).join("\n")}`,
    );
  }

  if (request.resolution === null) {
    parts.push(
      `Es el turno inicial: todavía no hubo acción del jugador. Narrá la ` +
        `escena de apertura del mundo "${request.world.name}".`,
    );
  } else {
    const r = request.resolution;
    parts.push(
      `El jugador intentó: "${request.playerAction}". ` +
        `Resultado mecánico YA CALCULADO (no lo recalcules): ${r.outcome}, ` +
        `tirada d20 ${r.roll}, total ${r.total} vs dificultad ${r.difficulty}` +
        (r.isNatural20 ? " (20 natural)" : "") +
        (r.isNatural1 ? " (1 natural)" : "") +
        `. Narrá este resultado con estilo; no decidas si tuvo éxito, eso ya ` +
        `está decidido.`,
    );
  }

  return parts.join("\n\n");
}
