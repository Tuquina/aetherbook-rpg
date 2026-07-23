import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { GeminiNarratorAdapter } from "./gemini_narrator_adapter.ts";
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
    attribute: 2,
    modifiers: 0,
    roll: 10,
    difficulty: 12,
    total: 12,
    isNatural20: false,
    isNatural1: false,
  },
};

function geminiResponse(text: string): Response {
  return new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }),
    { status: 200 },
  );
}

const VALID_JSON =
  '{"narration":"Meditás en calma.","suggested_choices":["Seguir"],' +
  '"state_deltas":[{"type":"exp","key":"exp","value":50}],' +
  '"image_prompt":"un monje","tone":"sereno"}';

Deno.test("parses a valid structured-output reply on the first try", async () => {
  let calls = 0;
  const adapter = new GeminiNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() => {
      calls++;
      return Promise.resolve(geminiResponse(VALID_JSON));
    }) as typeof fetch,
  });

  const result = await adapter.narrate(request);
  assertEquals(result.narration, "Meditás en calma.");
  assertEquals(calls, 1);
});

Deno.test("retries once with a repair prompt when JSON is broken, then succeeds", async () => {
  let calls = 0;
  const adapter = new GeminiNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() => {
      calls++;
      if (calls === 1) {
        return Promise.resolve(geminiResponse('{"narration": "roto" '));
      }
      return Promise.resolve(geminiResponse(VALID_JSON));
    }) as typeof fetch,
  });

  const result = await adapter.narrate(request);
  assertEquals(result.narration, "Meditás en calma.");
  assertEquals(calls, 2);
});

Deno.test("throws NarratorProviderError when JSON is broken twice in a row", async () => {
  const adapter = new GeminiNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.resolve(geminiResponse('{"narration": "roto" '))) as typeof fetch,
  });

  await assertRejects(() => adapter.narrate(request), NarratorProviderError);
});

Deno.test("maps HTTP 429 to a rate-limit NarratorProviderError", async () => {
  const adapter = new GeminiNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.resolve(
        new Response("quota exceeded", { status: 429 }),
      )) as typeof fetch,
  });

  const error = await assertRejects(
    () => adapter.narrate(request),
    NarratorProviderError,
  );
  assertEquals((error as NarratorProviderError).isRateLimit, true);
});

Deno.test("wraps a network failure as a non-rate-limit provider error", async () => {
  const adapter = new GeminiNarratorAdapter({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.reject(new Error("DNS failure"))) as unknown as typeof fetch,
  });

  const error = await assertRejects(
    () => adapter.narrate(request),
    NarratorProviderError,
  );
  assertEquals((error as NarratorProviderError).isRateLimit, false);
});

Deno.test("sends the API key and model in the request URL", async () => {
  let capturedUrl = "";
  const adapter = new GeminiNarratorAdapter({
    apiKey: "secret-123",
    model: "gemini-custom-model",
    fetchImpl: ((url: string) => {
      capturedUrl = url;
      return Promise.resolve(geminiResponse(VALID_JSON));
    }) as unknown as typeof fetch,
  });

  await adapter.narrate(request);
  assertEquals(
    capturedUrl,
    "https://generativelanguage.googleapis.com/v1beta/models/" +
      "gemini-custom-model:generateContent?key=secret-123",
  );
});
