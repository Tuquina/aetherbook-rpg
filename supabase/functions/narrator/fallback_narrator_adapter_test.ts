import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  AllNarratorProvidersFailedError,
  FallbackNarratorAdapter,
} from "./fallback_narrator_adapter.ts";
import { NarratorProviderError } from "./types.ts";
import type { NarratorAdapter, NarratorRequest, NarratorResponse } from "./types.ts";

const request: NarratorRequest = {
  world: {
    slug: "xianxia",
    name: "El Sendero del Qi",
    tone: "épico",
    systemPrompt: "",
    imageStyleSuffix: "",
  },
  character: {
    name: "Discípulo",
    level: 1,
    exp: 0,
    attributes: {},
    resources: {},
  },
  playerAction: "meditar",
  resolution: null,
};

function fakeResponse(narration: string): NarratorResponse {
  return {
    narration,
    suggested_choices: [],
    state_deltas: [],
    image_prompt: "",
    tone: "",
  };
}

class StubAdapter implements NarratorAdapter {
  calls = 0;
  constructor(readonly name: string, private readonly behavior: () => Promise<NarratorResponse>) {}
  narrate(_request: NarratorRequest): Promise<NarratorResponse> {
    this.calls++;
    return this.behavior();
  }
}

Deno.test("returns the primary's response when it succeeds", async () => {
  const primary = new StubAdapter("primary", () =>
    Promise.resolve(fakeResponse("desde primary")));
  const secondary = new StubAdapter("secondary", () =>
    Promise.resolve(fakeResponse("desde secondary")));

  const fallback = new FallbackNarratorAdapter([primary, secondary]);
  const result = await fallback.narrate(request);

  assertEquals(result.narration, "desde primary");
  assertEquals(secondary.calls, 0);
});

Deno.test("falls back to the next provider on a rate-limit error", async () => {
  const primary = new StubAdapter("gemini", () =>
    Promise.reject(new NarratorProviderError("quota exceeded", true)));
  const secondary = new StubAdapter("groq", () =>
    Promise.resolve(fakeResponse("desde groq")));

  const fallback = new FallbackNarratorAdapter([primary, secondary]);
  const result = await fallback.narrate(request);

  assertEquals(result.narration, "desde groq");
  assertEquals(primary.calls, 1);
  assertEquals(secondary.calls, 1);
});

Deno.test("falls back on non-rate-limit provider errors too (broken JSON, network)", async () => {
  const primary = new StubAdapter("gemini", () =>
    Promise.reject(new NarratorProviderError("broken JSON twice", false)));
  const secondary = new StubAdapter("groq", () =>
    Promise.resolve(fakeResponse("desde groq")));

  const fallback = new FallbackNarratorAdapter([primary, secondary]);
  const result = await fallback.narrate(request);

  assertEquals(result.narration, "desde groq");
});

Deno.test("throws AllNarratorProvidersFailedError when every provider fails", async () => {
  const primary = new StubAdapter("gemini", () =>
    Promise.reject(new NarratorProviderError("quota exceeded", true)));
  const secondary = new StubAdapter("groq", () =>
    Promise.reject(new NarratorProviderError("also down", false)));

  const fallback = new FallbackNarratorAdapter([primary, secondary]);

  const error = await assertRejects(
    () => fallback.narrate(request),
    AllNarratorProvidersFailedError,
  );
  assertEquals((error as AllNarratorProvidersFailedError).attempts.length, 2);
});

Deno.test("tries providers strictly in chain order", async () => {
  const order: string[] = [];
  const first = new StubAdapter("first", () => {
    order.push("first");
    return Promise.reject(new NarratorProviderError("down", false));
  });
  const second = new StubAdapter("second", () => {
    order.push("second");
    return Promise.reject(new NarratorProviderError("down", false));
  });
  const third = new StubAdapter("third", () => {
    order.push("third");
    return Promise.resolve(fakeResponse("desde third"));
  });

  const fallback = new FallbackNarratorAdapter([first, second, third]);
  await fallback.narrate(request);

  assertEquals(order, ["first", "second", "third"]);
});

Deno.test("rejects construction with an empty chain", () => {
  let threw = false;
  try {
    new FallbackNarratorAdapter([]);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
