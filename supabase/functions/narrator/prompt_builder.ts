// Builds the layered prompt described in CLAUDE.md §5.1: world system prompt,
// compressed state, immediate context, the already-resolved action, and the
// output-format instruction. Shared by every provider adapter so the prompt
// shape never drifts between Gemini and Groq.

import type { NarratorRequest } from "./types.ts";

// Applies to every world, every provider — the one place that shapes *how*
// the narrator writes, as opposed to each world's own system prompt (which
// only covers *what* it writes: setting, tone, canon, hard rules). Kept
// separate and always appended so a new world gets this for free without
// having to restate it, and so a style tweak here doesn't require editing
// every world's JSON.
export const HUMAN_STYLE_INSTRUCTION =
  `ESTILO DE ESCRITURA (se aplica siempre, además del tono propio del mundo):\n` +
  `- Escribí como una persona narrando, no como una IA generando texto. Nada ` +
  `de relleno ni de prosa genérica que podría pertenecer a cualquier escena.\n` +
  `- Alterná drásticamente la longitud de las oraciones. Una frase de cinco ` +
  `palabras puede ir seguida de otra mucho más larga, con giros, comas y ` +
  `una idea que se estira antes de cerrar — así respira un pensamiento real. ` +
  `Nunca repitas el mismo largo de oración dos veces seguidas.\n` +
  `- Separá el texto en párrafos (saltos de línea dobles). Nunca un solo ` +
  `bloque compacto de principio a fin.\n` +
  `- No cierres cada escena con una frase prolija ni una conclusión ` +
  `redonda. Algunas escenas terminan en seco, a mitad de un gesto o una ` +
  `duda, sin resolver la tensión.\n` +
  `- Evitá clichés y frases hechas: "el aire se cargó de tensión", "una ` +
  `mezcla de emociones", "poco sabías que", "el destino tenía otros ` +
  `planes", "sin previo aviso", "un silencio sepulcral", "el corazón le ` +
  `latía con fuerza", "no podía creer lo que veían sus ojos". Si una frase ` +
  `te suena a algo ya leído mil veces, reescribila.\n` +
  `- Inspirate en el pulso de Dan Brown (capítulos cortos, ganchos, ` +
  `urgencia que empuja a seguir leyendo) y en el detalle sensorial y la voz ` +
  `propia de cada personaje al estilo J.K. Rowling. Es una referencia de ` +
  `ritmo y textura, nunca copies frases ni construcciones suyas.\n` +
  `- El personaje tiene un nombre (está en "Estado del personaje" más ` +
  `abajo) — usalo con naturalidad de tanto en tanto, como lo haría alguien ` +
  `que lo conoce. No narres todo en "vos" sin nombrarlo nunca.`;

export const OUTPUT_INSTRUCTION =
  `Devolvé SOLO un objeto JSON válido con esta forma exacta, sin markdown, ` +
  `sin backticks, sin preámbulo ni texto fuera del JSON:\n` +
  `{"narration": string, ` +
  `"suggested_choices": [{"id": string, "label": string, ` +
  `"intent"?: string, "expected_check"?: {"attribute": string, ` +
  `"difficulty_id"?: string}}], ` +
  `"proposed_state_deltas": [{"type": "flag"|"exp"|"resource"|"meter"|` +
  `"relationship", "key": string, "value": boolean|number, ` +
  `"operation": "increment", "reason": string}], ` +
  `"image_prompt": string, "tone": string, "memory_facts": string[], ` +
  `"node_status": "active"|"ready_to_exit"}`;

export function buildSystemPrompt(request: NarratorRequest): string {
  return [request.world.systemPrompt, HUMAN_STYLE_INSTRUCTION, OUTPUT_INSTRUCTION]
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

  if (request.nodeFixedReveals && request.nodeFixedReveals.length > 0) {
    parts.push(
      `Hechos que DEBÉS incluir en esta escena:\n` +
        request.nodeFixedReveals.map((f) => `- ${f}`).join("\n"),
    );
  }

  if (request.nodeForbiddenReveals && request.nodeForbiddenReveals.length > 0) {
    parts.push(
      `Nunca reveles todavía:\n` +
        request.nodeForbiddenReveals.map((f) => `- ${f}`).join("\n"),
    );
  }

  if (request.nodeGoal) {
    parts.push(
      `Estás narrando un tramo generativo acotado. Objetivo único de este ` +
        `tramo (no generes otro hito, antagonista principal ni solución ` +
        `final): ${request.nodeGoal}`,
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
      `El jugador intentó: "${request.playerAction}" (chequeo de ` +
        `${r.attributeKey}). ` +
        `Resultado mecánico YA CALCULADO (no lo recalcules): ${r.outcome}, ` +
        `tirada d20 ${r.roll}, total ${r.total} vs dificultad ${r.difficulty}` +
        (r.isNatural20 ? " (20 natural)" : "") +
        (r.isNatural1 ? " (1 natural)" : "") +
        `. Narrá este resultado con estilo, reflejando que fue un chequeo de ` +
        `${r.attributeKey}; no decidas si tuvo éxito, eso ya está decidido.`,
    );
  }

  return parts.join("\n\n");
}
