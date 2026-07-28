import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import {
  buildAvoidedThemesInstruction,
  buildSystemPrompt,
  buildToneInstruction,
  buildUserPrompt,
  buildVowInstruction,
} from "./prompt_builder.ts";
import type { NarratorRequest } from "./types.ts";

const baseRequest: NarratorRequest = {
  world: {
    slug: "xianxia",
    name: "El Sendero del Qi",
    tone: "épico",
    systemPrompt: "Eres el Game Master de un mundo xianxia.",
    imageStyleSuffix: "arte xianxia",
  },
  character: {
    name: "Discípulo",
    level: 1,
    exp: 0,
    attributes: { espiritu: 2 },
    resources: { qi: 10 },
  },
  playerAction: "",
  resolution: null,
};

Deno.test("system prompt includes the world's prompt and the output instruction", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertStringIncludes(prompt, "Game Master");
  assertStringIncludes(prompt, "SOLO un objeto JSON válido");
});

Deno.test("system prompt always includes the shared human-style instruction", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertStringIncludes(prompt, "ESTILO DE ESCRITURA");
  assertStringIncludes(prompt, "Alterna drásticamente la longitud");
  assertStringIncludes(prompt, "Evita clichés");
  assertStringIncludes(prompt, "úsalo con naturalidad");
});

Deno.test("system prompt always forbids voseo and requires neutral tuteo Spanish", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertStringIncludes(prompt, "IDIOMA Y REGISTRO");
  assertStringIncludes(prompt, "NUNCA voseo rioplatense");
  assertStringIncludes(prompt, '"vos"');
  assertStringIncludes(prompt, "SIEMPRE");
  assertStringIncludes(prompt, '"tú"');
});

Deno.test("user prompt asks to continue naturally when resolution is null and playerAction is empty", () => {
  const prompt = buildUserPrompt(baseRequest);
  assertStringIncludes(prompt, "no especificó una acción puntual");
  assertStringIncludes(prompt, "dejar que la historia avance sola");
});

Deno.test("user prompt narrates an unresolved-but-specific action when resolution is null and playerAction is set (unconditional curated choice)", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    playerAction: "Ir a la Torre de las Campanas",
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, 'El jugador hizo esto: "Ir a la Torre de las Campanas"');
  assertStringIncludes(prompt, "No hizo falta ninguna tirada");
  assertEquals(prompt.includes("no especificó una acción puntual"), false);
});

Deno.test("user prompt includes the resolved mechanics, not a request to resolve them", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    playerAction: "forzar la puerta",
    resolution: {
      outcome: "success",
      attributeKey: "espiritu",
      attribute: 2,
      modifiers: 0,
      roll: 10,
      difficulty: 12,
      total: 12,
      isNatural20: false,
      isNatural1: false,
    },
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, "forzar la puerta");
  assertStringIncludes(prompt, "success");
  assertStringIncludes(prompt, "total 12 vs dificultad 12");
  assertStringIncludes(prompt, "no decidas si tuvo éxito");
  assertStringIncludes(prompt, "chequeo de espiritu");
});

Deno.test("user prompt includes recent turns when present", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    recentTurns: ["Meditar -> sentiste el qi fluir"],
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, "Contexto reciente");
  assertStringIncludes(prompt, "sentiste el qi fluir");
});

Deno.test("user prompt includes the memory digest when present", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    memoryDigest: "El discípulo dejó su aldea natal buscando un maestro.",
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, "Diario de la historia hasta ahora");
  assertStringIncludes(prompt, "dejó su aldea natal");
});

Deno.test("user prompt omits the digest section when absent or blank", () => {
  const withoutDigest = buildUserPrompt(baseRequest);
  assertEquals(withoutDigest.includes("Diario de la historia"), false);

  const blankDigest = buildUserPrompt({ ...baseRequest, memoryDigest: "   " });
  assertEquals(blankDigest.includes("Diario de la historia"), false);
});

Deno.test("user prompt includes fixed reveals the narrator must include", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    nodeFixedReveals: ["Siete personas ya fueron borradas."],
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, "DEBES incluir");
  assertStringIncludes(prompt, "Siete personas ya fueron borradas.");
});

Deno.test("user prompt includes forbidden reveals", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    nodeForbiddenReveals: ["El ritual original distribuía recuerdos."],
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, "Nunca reveles");
  assertStringIncludes(prompt, "El ritual original distribuía recuerdos.");
});

Deno.test("user prompt includes the corridor's single goal", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    nodeGoal: "Obtener exactamente un access_token.",
  };
  const prompt = buildUserPrompt(request);
  assertStringIncludes(prompt, "tramo generativo acotado");
  assertStringIncludes(prompt, "Obtener exactamente un access_token.");
});

Deno.test("system prompt omits the freeform-choices instruction for a curated world", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertEquals(prompt.includes("OPCIONES SUGERIDAS"), false);
});

Deno.test("system prompt includes the freeform-choices instruction when isFreeform is true", () => {
  const prompt = buildSystemPrompt({ ...baseRequest, isFreeform: true });
  assertStringIncludes(prompt, "OPCIONES SUGERIDAS");
  assertStringIncludes(prompt, "preferentemente 2");
  assertStringIncludes(prompt, "SIEMPRE puede escribir su propia acción");
  assertStringIncludes(prompt, '"suggested_choices": []');
});

Deno.test("buildToneInstruction returns empty for null/undefined (no tone chosen)", () => {
  assertEquals(buildToneInstruction(null), "");
  assertEquals(buildToneInstruction(undefined), "");
});

Deno.test("buildToneInstruction names the tone and tells the narrator mechanics don't change", () => {
  const instruction = buildToneInstruction({ label: "Épico", blurb: "Grande, mítico" });
  assertStringIncludes(instruction, '"Épico"');
  assertStringIncludes(instruction, "Grande, mítico");
  assertStringIncludes(instruction, "nunca *qué* pasa mecánicamente");
});

Deno.test("system prompt omits any tone instruction when chosenTone is absent", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertEquals(prompt.includes("TONO ELEGIDO POR EL JUGADOR"), false);
});

Deno.test("system prompt includes the tone instruction when chosenTone is present", () => {
  const prompt = buildSystemPrompt({
    ...baseRequest,
    chosenTone: { label: "Ácido", blurb: "Seco, irónico" },
  });
  assertStringIncludes(prompt, "TONO ELEGIDO POR EL JUGADOR");
  assertStringIncludes(prompt, '"Ácido"');
  assertStringIncludes(prompt, "Seco, irónico");
});

Deno.test("buildVowInstruction returns empty for null/undefined/blank (no vow at chargen)", () => {
  assertEquals(buildVowInstruction(null), "");
  assertEquals(buildVowInstruction(undefined), "");
  assertEquals(buildVowInstruction("   "), "");
});

Deno.test("buildVowInstruction names the vow and tells the narrator how to propose vow_status", () => {
  const instruction = buildVowInstruction("No dejo atrás a nadie que me haya dado su nombre.");
  assertStringIncludes(instruction, "No dejo atrás a nadie que me haya dado su nombre.");
  assertStringIncludes(instruction, '"type": "vow_status"');
  assertStringIncludes(instruction, "puesto_a_prueba");
  assertStringIncludes(instruction, "roto");
});

Deno.test("system prompt omits any vow instruction when vowText is absent", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertEquals(prompt.includes("JURAMENTO DEL PERSONAJE"), false);
});

Deno.test("system prompt includes the vow instruction when vowText is present", () => {
  const prompt = buildSystemPrompt({
    ...baseRequest,
    vowText: "No vuelvo a firmar nada con mi nombre real.",
  });
  assertStringIncludes(prompt, "JURAMENTO DEL PERSONAJE");
  assertStringIncludes(prompt, "No vuelvo a firmar nada con mi nombre real.");
});

Deno.test("buildAvoidedThemesInstruction returns empty for an empty/absent list", () => {
  assertEquals(buildAvoidedThemesInstruction(null), "");
  assertEquals(buildAvoidedThemesInstruction(undefined), "");
  assertEquals(buildAvoidedThemesInstruction([]), "");
});

Deno.test("buildAvoidedThemesInstruction lists every theme and forbids depicting them", () => {
  const instruction = buildAvoidedThemesInstruction(["Contenido sexual", "Crueldad animal"]);
  assertStringIncludes(instruction, "Contenido sexual");
  assertStringIncludes(instruction, "Crueldad animal");
  assertStringIncludes(instruction, "regla no negociable");
});

Deno.test("system prompt omits the avoided-themes instruction when none are set", () => {
  const prompt = buildSystemPrompt(baseRequest);
  assertEquals(prompt.includes("TEMAS A EVITAR"), false);
});

Deno.test("system prompt includes the avoided-themes instruction when set", () => {
  const prompt = buildSystemPrompt({
    ...baseRequest,
    avoidedThemes: ["Terror corporal"],
  });
  assertStringIncludes(prompt, "TEMAS A EVITAR");
  assertStringIncludes(prompt, "Terror corporal");
});

Deno.test("user prompt omits node-context sections when absent", () => {
  const prompt = buildUserPrompt(baseRequest);
  assertEquals(prompt.includes("DEBES incluir"), false);
  assertEquals(prompt.includes("Nunca reveles"), false);
  assertEquals(prompt.includes("tramo generativo acotado"), false);
});
