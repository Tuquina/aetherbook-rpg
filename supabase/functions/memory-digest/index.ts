// Edge Function entrypoint for the memory digest (CLAUDE.md §6, GDD §5.3).
// Kept separate from the `narrator` function: different contract (plain
// text, not the narration JSON), different concern (summarization, not
// storytelling), even though both currently call Groq.

import { GroqSummarizer, SummarizerError } from "./groq_summarizer.ts";
import type { DigestRequest } from "./types.ts";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export function isDigestRequest(body: unknown): body is DigestRequest {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return Array.isArray(b.turnsToSummarize);
}

export async function handleRequest(
  req: Request,
  summarizerFactory: () => GroqSummarizer | null = defaultSummarizerFactory,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON request body" }, 400);
  }

  if (!isDigestRequest(body)) {
    return jsonResponse({ error: "expected { turnsToSummarize, previousDigest? }" }, 400);
  }

  const summarizer = summarizerFactory();
  if (summarizer === null) {
    return jsonResponse({ error: "no summarizer configured (missing GROQ_API_KEY)" }, 500);
  }

  try {
    const summary = await summarizer.summarize(body);
    return jsonResponse({ summary }, 200);
  } catch (e) {
    if (e instanceof SummarizerError) {
      return jsonResponse({ error: e.message, isRateLimit: e.isRateLimit }, 502);
    }
    return jsonResponse({ error: `unexpected error: ${e}` }, 500);
  }
}

function defaultSummarizerFactory(): GroqSummarizer | null {
  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) return null;
  return new GroqSummarizer({
    apiKey,
    model: Deno.env.get("GROQ_MODEL") ?? undefined,
  });
}

if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
