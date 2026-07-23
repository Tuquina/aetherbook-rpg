import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { buildSystemPrompt, buildUserPrompt } from "./prompt_builder.ts";
import type { NarratorRequest } from "./types.ts";

const baseRequest: NarratorRequest = {
  world: {
    slug: "xianxia",
    name: "El Sendero del Qi",
    tone: "épico",
    systemPrompt: "Sos el Game Master de un mundo xianxia.",
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

Deno.test("user prompt narrates the opening scene when resolution is null", () => {
  const prompt = buildUserPrompt(baseRequest);
  assertStringIncludes(prompt, "turno inicial");
  assertStringIncludes(prompt, "El Sendero del Qi");
});

Deno.test("user prompt includes the resolved mechanics, not a request to resolve them", () => {
  const request: NarratorRequest = {
    ...baseRequest,
    playerAction: "forzar la puerta",
    resolution: {
      outcome: "success",
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
