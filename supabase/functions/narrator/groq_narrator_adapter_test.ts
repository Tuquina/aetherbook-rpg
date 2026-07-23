import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { GroqNarratorAdapter } from "./groq_narrator_adapter.ts";
import { NarratorProviderError } from "./types.ts";
import type { NarratorRequest } from "./types.ts";

const request: NarratorRequest = {
  world: {
    slug: "xianxia",
    name: "El Sendero del Qi",
    tone: "épico",
    systemPrompt: "Sos el Game Master.",
    imageStyleSuffix: "arte xianxia",
  },
  character: {
    name: "Discípulo",
    level: 1,
    exp: 0,
    attributes: { espiritu: 2 },
    resources: { qi: 10 },
  },
  playerAction: "meditar",
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

function groqResponse(content: string): Response {
  return new Response(
    JSON.stringify({ choices: [{ message: { content } }] }),
    { status: 200 },
  );
}

const VALID_JSON =
  '{"narration":"Meditás en calma.","suggested_choices":["Seguir"],' +
  '"state_deltas":[{"type":"exp","key":"exp","value":50}],' +
  '"image_prompt":"un monje","tone":"sereno"}';

Deno.test("parses a valid JSON-mode reply on the first try", async () => {
  const adapter = new GroqNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() => Promise.resolve(groqResponse(VALID_JSON))) as typeof fetch,
  });

  const result = await adapter.narrate(request);
  assertEquals(result.narration, "Meditás en calma.");
});

Deno.test("retries once with a repair prompt when JSON is broken", async () => {
  let calls = 0;
  const adapter = new GroqNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() => {
      calls++;
      return Promise.resolve(
        groqResponse(calls === 1 ? '{"narration": "roto" ' : VALID_JSON),
      );
    }) as typeof fetch,
  });

  const result = await adapter.narrate(request);
  assertEquals(result.narration, "Meditás en calma.");
  assertEquals(calls, 2);
});

Deno.test("maps HTTP 429 to a rate-limit NarratorProviderError", async () => {
  const adapter = new GroqNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.resolve(
        new Response("rate limited", { status: 429 }),
      )) as typeof fetch,
  });

  const error = await assertRejects(
    () => adapter.narrate(request),
    NarratorProviderError,
  );
  assertEquals((error as NarratorProviderError).isRateLimit, true);
});

Deno.test("sends bearer auth and the configured model", async () => {
  let capturedAuth: string | null = null;
  let capturedBody: Record<string, unknown> = {};
  const adapter = new GroqNarratorAdapter({
    apiKey: "secret-456",
    model: "custom-groq-model",
    fetchImpl: ((_url: string, init: RequestInit) => {
      capturedAuth = (init.headers as Record<string, string>)["Authorization"];
      capturedBody = JSON.parse(init.body as string);
      return Promise.resolve(groqResponse(VALID_JSON));
    }) as unknown as typeof fetch,
  });

  await adapter.narrate(request);
  assertEquals(capturedAuth, "Bearer secret-456");
  assertEquals(capturedBody.model, "custom-groq-model");
  assertEquals(capturedBody.response_format, { type: "json_object" });
});
