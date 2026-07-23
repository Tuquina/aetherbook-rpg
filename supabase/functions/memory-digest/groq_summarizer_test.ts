import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";
import { GroqSummarizer, SummarizerError } from "./groq_summarizer.ts";
import type { DigestRequest } from "./types.ts";

function groqResponse(content: string): Response {
  return new Response(
    JSON.stringify({ choices: [{ message: { content } }] }),
    { status: 200 },
  );
}

const request: DigestRequest = {
  turnsToSummarize: [
    { playerAction: "Meditar", narration: "Sentiste el qi fluir." },
    { playerAction: "Explorar", narration: "Encontraste un templo." },
  ],
};

Deno.test("returns the summary text from Groq's response", async () => {
  const summarizer = new GroqSummarizer({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.resolve(groqResponse("El discípulo meditó y halló un templo."))) as typeof fetch,
  });

  const summary = await summarizer.summarize(request);
  assertEquals(summary, "El discípulo meditó y halló un templo.");
});

Deno.test("includes the previous digest and new turns in the prompt sent to Groq", async () => {
  let capturedBody: Record<string, unknown> = {};
  const summarizer = new GroqSummarizer({
    apiKey: "test-key",
    fetchImpl: ((_url: string, init: RequestInit) => {
      capturedBody = JSON.parse(init.body as string);
      return Promise.resolve(groqResponse("resumen"));
    }) as unknown as typeof fetch,
  });

  await summarizer.summarize({
    ...request,
    previousDigest: "El discípulo dejó su aldea natal.",
  });

  const messages = capturedBody.messages as { role: string; content: string }[];
  const userMessage = messages.find((m) => m.role === "user")!;
  assertStringIncludes(userMessage.content, "Diario previo");
  assertStringIncludes(userMessage.content, "dejó su aldea natal");
  assertStringIncludes(userMessage.content, "Meditar");
  assertStringIncludes(userMessage.content, "Encontraste un templo");
});

Deno.test("omits the 'Diario previo' section when there is no previous digest", async () => {
  let capturedBody: Record<string, unknown> = {};
  const summarizer = new GroqSummarizer({
    apiKey: "test-key",
    fetchImpl: ((_url: string, init: RequestInit) => {
      capturedBody = JSON.parse(init.body as string);
      return Promise.resolve(groqResponse("resumen"));
    }) as unknown as typeof fetch,
  });

  await summarizer.summarize(request);

  const messages = capturedBody.messages as { role: string; content: string }[];
  const userMessage = messages.find((m) => m.role === "user")!;
  assertEquals(userMessage.content.includes("Diario previo"), false);
});

Deno.test("maps HTTP 429 to a rate-limit SummarizerError", async () => {
  const summarizer = new GroqSummarizer({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.resolve(new Response("rate limited", { status: 429 }))) as typeof fetch,
  });

  const error = await assertRejects(
    () => summarizer.summarize(request),
    SummarizerError,
  );
  assertEquals((error as SummarizerError).isRateLimit, true);
});

Deno.test("throws when Groq's response has no content", async () => {
  const summarizer = new GroqSummarizer({
    apiKey: "test-key",
    fetchImpl: (() =>
      Promise.resolve(
        new Response(JSON.stringify({ choices: [{}] }), { status: 200 }),
      )) as typeof fetch,
  });

  await assertRejects(() => summarizer.summarize(request), SummarizerError);
});
