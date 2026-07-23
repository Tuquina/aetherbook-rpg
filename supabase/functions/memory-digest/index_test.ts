import { assertEquals } from "jsr:@std/assert@1";
import { handleRequest, isDigestRequest } from "./index.ts";
import { GroqSummarizer } from "./groq_summarizer.ts";

const validBody = {
  turnsToSummarize: [
    { playerAction: "Meditar", narration: "Sentiste el qi fluir." },
  ],
};

function fakeSummarizer(summary = "resumen de prueba"): GroqSummarizer {
  const s = new GroqSummarizer({ apiKey: "unused" });
  s.summarize = () => Promise.resolve(summary);
  return s;
}

Deno.test("responds to OPTIONS with CORS headers", async () => {
  const req = new Request("http://local/memory-digest", { method: "OPTIONS" });
  const res = await handleRequest(req, () => fakeSummarizer());
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("rejects non-POST, non-OPTIONS methods", async () => {
  const req = new Request("http://local/memory-digest", { method: "GET" });
  const res = await handleRequest(req, () => fakeSummarizer());
  assertEquals(res.status, 405);
});

Deno.test("returns 400 on invalid JSON body", async () => {
  const req = new Request("http://local/memory-digest", {
    method: "POST",
    body: "{not json",
  });
  const res = await handleRequest(req, () => fakeSummarizer());
  assertEquals(res.status, 400);
});

Deno.test("returns 400 when turnsToSummarize is missing", async () => {
  const req = new Request("http://local/memory-digest", {
    method: "POST",
    body: JSON.stringify({ foo: "bar" }),
  });
  const res = await handleRequest(req, () => fakeSummarizer());
  assertEquals(res.status, 400);
});

Deno.test("returns 500 when no summarizer is configured", async () => {
  const req = new Request("http://local/memory-digest", {
    method: "POST",
    body: JSON.stringify(validBody),
  });
  const res = await handleRequest(req, () => null);
  assertEquals(res.status, 500);
});

Deno.test("returns 200 with the summary on a valid request", async () => {
  const req = new Request("http://local/memory-digest", {
    method: "POST",
    body: JSON.stringify(validBody),
  });
  const res = await handleRequest(req, () => fakeSummarizer("un resumen breve"));
  assertEquals(res.status, 200);
  const json = await res.json();
  assertEquals(json.summary, "un resumen breve");
});

Deno.test("isDigestRequest accepts a well-formed request", () => {
  assertEquals(isDigestRequest(validBody), true);
});

Deno.test("isDigestRequest rejects a malformed request", () => {
  assertEquals(isDigestRequest({}), false);
  assertEquals(isDigestRequest(null), false);
});
