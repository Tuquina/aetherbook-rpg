import { assertEquals } from "jsr:@std/assert@1";
import { handleRequest, isNarratorRequest } from "./index.ts";
import type { NarratorAdapter, NarratorRequest, NarratorResponse } from "./types.ts";

const validBody: NarratorRequest = {
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

function fakeChain(narration = "hola"): NarratorAdapter[] {
  return [
    {
      name: "stub",
      narrate: (_r): Promise<NarratorResponse> =>
        Promise.resolve({
          narration,
          suggested_choices: [],
          proposed_state_deltas: [],
          image_prompt: "",
          tone: "",
          memory_facts: [],
          node_status: "active",
        }),
    },
  ];
}

Deno.test("responds to OPTIONS with CORS headers and no body", async () => {
  const req = new Request("http://local/narrator", { method: "OPTIONS" });
  const res = await handleRequest(req, fakeChain);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("rejects non-POST, non-OPTIONS methods", async () => {
  const req = new Request("http://local/narrator", { method: "GET" });
  const res = await handleRequest(req, fakeChain);
  assertEquals(res.status, 405);
});

Deno.test("returns 400 on invalid JSON body", async () => {
  const req = new Request("http://local/narrator", {
    method: "POST",
    body: "{not json",
  });
  const res = await handleRequest(req, fakeChain);
  assertEquals(res.status, 400);
});

Deno.test("returns 400 when the body doesn't match the contract", async () => {
  const req = new Request("http://local/narrator", {
    method: "POST",
    body: JSON.stringify({ foo: "bar" }),
  });
  const res = await handleRequest(req, fakeChain);
  assertEquals(res.status, 400);
});

Deno.test("returns 500 when no provider is configured", async () => {
  const req = new Request("http://local/narrator", {
    method: "POST",
    body: JSON.stringify(validBody),
  });
  const res = await handleRequest(req, () => []);
  assertEquals(res.status, 500);
});

Deno.test("returns 200 with the narrator's JSON on a valid request", async () => {
  const req = new Request("http://local/narrator", {
    method: "POST",
    body: JSON.stringify(validBody),
  });
  const res = await handleRequest(req, () => fakeChain("narración de prueba"));
  assertEquals(res.status, 200);
  const json = await res.json();
  assertEquals(json.narration, "narración de prueba");
});

Deno.test("isNarratorRequest accepts a well-formed request", () => {
  assertEquals(isNarratorRequest(validBody), true);
});

Deno.test("isNarratorRequest rejects a malformed request", () => {
  assertEquals(isNarratorRequest({ world: {} }), false);
  assertEquals(isNarratorRequest(null), false);
  assertEquals(isNarratorRequest("string"), false);
});
