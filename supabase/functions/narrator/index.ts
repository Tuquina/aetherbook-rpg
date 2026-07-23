// Edge Function entrypoint (CLAUDE.md §4, §7): the only place that touches
// HTTP and environment secrets. All actual narration logic lives in the
// adapters/orchestrator above — this file just wires them up and translates
// to/from HTTP. API keys never leave the server (CLAUDE.md §2.4).

import { GeminiNarratorAdapter } from "./gemini_narrator_adapter.ts";
import { GroqNarratorAdapter } from "./groq_narrator_adapter.ts";
import {
  AllNarratorProvidersFailedError,
  FallbackNarratorAdapter,
} from "./fallback_narrator_adapter.ts";
import type { NarratorAdapter, NarratorRequest } from "./types.ts";

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

export function buildChain(): NarratorAdapter[] {
  const chain: NarratorAdapter[] = [];

  const geminiKey = Deno.env.get("GEMINI_API_KEY");
  if (geminiKey) {
    chain.push(
      new GeminiNarratorAdapter({
        apiKey: geminiKey,
        model: Deno.env.get("GEMINI_MODEL") ?? undefined,
      }),
    );
  }

  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (groqKey) {
    chain.push(
      new GroqNarratorAdapter({
        apiKey: groqKey,
        model: Deno.env.get("GROQ_MODEL") ?? undefined,
      }),
    );
  }

  return chain;
}

/** Narrow, defensive validation of the incoming body shape. */
export function isNarratorRequest(body: unknown): body is NarratorRequest {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return (
    typeof b.world === "object" &&
    typeof b.character === "object" &&
    typeof b.playerAction === "string" &&
    (b.resolution === null || typeof b.resolution === "object")
  );
}

/**
 * The pure request handler, factored out of `Deno.serve` so it can be unit
 * tested without binding a real port. `chainFactory` is injectable so tests
 * can supply stub providers instead of hitting Gemini/Groq.
 */
export async function handleRequest(
  req: Request,
  chainFactory: () => NarratorAdapter[] = buildChain,
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

  if (!isNarratorRequest(body)) {
    return jsonResponse(
      { error: "expected { world, character, playerAction, resolution }" },
      400,
    );
  }

  const chain = chainFactory();
  if (chain.length === 0) {
    return jsonResponse(
      { error: "no narrator provider configured (missing API keys)" },
      500,
    );
  }

  const narrator = new FallbackNarratorAdapter(chain);

  try {
    const response = await narrator.narrate(body);
    return jsonResponse(response, 200);
  } catch (e) {
    if (e instanceof AllNarratorProvidersFailedError) {
      return jsonResponse(
        {
          error: "all narrator providers failed",
          attempts: e.attempts.map((a) => ({
            provider: a.provider,
            error: String(a.error),
          })),
        },
        502,
      );
    }
    return jsonResponse({ error: `unexpected error: ${e}` }, 500);
  }
}

// Only start a real server when this module is the Deno entrypoint (i.e. when
// deployed), never when it's merely imported by a test.
if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
