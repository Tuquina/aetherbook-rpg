// Edge Function entrypoint for scene images (CLAUDE.md §4, §7; GDD §6/§7.2):
// the only place that touches Storage write credentials. Never calls the
// image provider from the client — same broker pattern as `narrator`.
//
// Flow: hash the prompt -> HEAD the deterministic public Storage URL (cache
// hit if 200) -> otherwise fetch from Pollinations.ai (no API key needed)
// -> upload to Storage with the service-role key -> return the public URL.
// Uses plain `fetch` throughout (no `@supabase/supabase-js` dependency),
// same style as the Gemini/Groq adapters in `narrator/`.

import { sha256Hex } from "./hash.ts";
import type { GenerateImageRequest } from "./types.ts";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const BUCKET = "scene-images";

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export function isGenerateImageRequest(
  body: unknown,
): body is GenerateImageRequest {
  if (typeof body !== "object" || body === null) return false;
  const b = body as Record<string, unknown>;
  return typeof b.prompt === "string" && b.prompt.trim().length > 0;
}

/** Dependencies injectable for tests — no real network/env needed. */
export interface GenerateImageDeps {
  fetchImpl: typeof fetch;
  supabaseUrl: string | undefined;
  serviceRoleKey: string | undefined;
}

function defaultDeps(): GenerateImageDeps {
  return {
    fetchImpl: fetch,
    supabaseUrl: Deno.env.get("SUPABASE_URL"),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  };
}

/**
 * The pure request handler, factored out of `Deno.serve` so it can be unit
 * tested without binding a real port (same shape as `narrator/index.ts`).
 */
export async function handleRequest(
  req: Request,
  deps: GenerateImageDeps = defaultDeps(),
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "method not allowed" }, 405);
  }

  if (!deps.supabaseUrl || !deps.serviceRoleKey) {
    return jsonResponse(
      { error: "Storage not configured (missing SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY)" },
      500,
    );
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid JSON request body" }, 400);
  }

  if (!isGenerateImageRequest(body)) {
    return jsonResponse({ error: "expected { prompt: string }" }, 400);
  }

  const hash = await sha256Hex(body.prompt);
  const objectPath = `${hash}.jpg`;
  const publicUrl =
    `${deps.supabaseUrl}/storage/v1/object/public/${BUCKET}/${objectPath}`;

  try {
    const cacheCheck = await deps.fetchImpl(publicUrl, { method: "HEAD" });
    if (cacheCheck.ok) {
      return jsonResponse({ imageUrl: publicUrl, cached: true }, 200);
    }
  } catch {
    // A network hiccup on the cache check just falls through to generating
    // fresh — never a hard failure for something this optional.
  }

  let imageBytes: ArrayBuffer;
  try {
    const providerUrl =
      `https://image.pollinations.ai/prompt/${encodeURIComponent(body.prompt)}` +
      `?width=1024&height=1024&nologo=true`;
    const providerResponse = await deps.fetchImpl(providerUrl);
    if (!providerResponse.ok) {
      return jsonResponse(
        { error: `image provider responded ${providerResponse.status}` },
        502,
      );
    }
    imageBytes = await providerResponse.arrayBuffer();
  } catch (e) {
    return jsonResponse({ error: `image provider request failed: ${e}` }, 502);
  }

  try {
    const uploadUrl =
      `${deps.supabaseUrl}/storage/v1/object/${BUCKET}/${objectPath}`;
    const uploadResponse = await deps.fetchImpl(uploadUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${deps.serviceRoleKey}`,
        "apikey": deps.serviceRoleKey,
        "Content-Type": "image/jpeg",
        "x-upsert": "true",
      },
      body: imageBytes,
    });
    if (!uploadResponse.ok) {
      return jsonResponse(
        { error: `Storage upload responded ${uploadResponse.status}` },
        502,
      );
    }
  } catch (e) {
    return jsonResponse({ error: `Storage upload failed: ${e}` }, 502);
  }

  return jsonResponse({ imageUrl: publicUrl, cached: false }, 200);
}

// Only start a real server when this module is the Deno entrypoint (i.e.
// when deployed), never when it's merely imported by a test.
if (import.meta.main) {
  Deno.serve((req) => handleRequest(req));
}
