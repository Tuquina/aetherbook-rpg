import { assertEquals } from "jsr:@std/assert@1";
import { handleRequest, type GenerateImageDeps } from "./index.ts";

const baseDeps = {
  supabaseUrl: "https://example.supabase.co",
  serviceRoleKey: "service-role-key",
};

function jsonRequest(body: unknown, method = "POST"): Request {
  const hasBody = method !== "OPTIONS" && method !== "GET" && method !== "HEAD";
  return new Request("https://example.com/generate-image", {
    method,
    headers: { "Content-Type": "application/json" },
    body: hasBody ? JSON.stringify(body) : undefined,
  });
}

/** Records every call and answers based on method/URL substring matches. */
class FakeFetch {
  calls: { url: string; method: string }[] = [];

  headStatus = 404;
  providerStatus = 200;
  uploadStatus = 200;

  fetch: typeof fetch = async (input, init) => {
    const url = typeof input === "string" ? input : (input as Request).url;
    const method = (init?.method ?? "GET").toUpperCase();
    this.calls.push({ url, method });

    if (method === "HEAD") {
      return new Response(null, { status: this.headStatus });
    }
    if (url.includes("image.pollinations.ai")) {
      return new Response(new Uint8Array([1, 2, 3]).buffer, {
        status: this.providerStatus,
      });
    }
    if (method === "POST" && url.includes("/storage/v1/object/")) {
      return new Response(null, { status: this.uploadStatus });
    }
    throw new Error(`unexpected fetch: ${method} ${url}`);
  };
}

Deno.test("responds to OPTIONS with CORS headers and no body", async () => {
  const response = await handleRequest(jsonRequest(null, "OPTIONS"));
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "*");
});

Deno.test("rejects non-POST, non-OPTIONS methods", async () => {
  const response = await handleRequest(jsonRequest({}, "GET"));
  assertEquals(response.status, 405);
});

Deno.test("returns 500 when Storage isn't configured", async () => {
  const fake = new FakeFetch();
  const response = await handleRequest(
    jsonRequest({ prompt: "una escena" }),
    { fetchImpl: fake.fetch, supabaseUrl: undefined, serviceRoleKey: undefined },
  );
  assertEquals(response.status, 500);
});

Deno.test("returns 400 on invalid JSON body", async () => {
  const request = new Request("https://example.com/generate-image", {
    method: "POST",
    body: "{not json",
  });
  const fake = new FakeFetch();
  const response = await handleRequest(request, {
    fetchImpl: fake.fetch,
    ...baseDeps,
  });
  assertEquals(response.status, 400);
});

Deno.test("returns 400 when the prompt is missing or blank", async () => {
  const fake = new FakeFetch();
  const deps: GenerateImageDeps = { fetchImpl: fake.fetch, ...baseDeps };

  const missing = await handleRequest(jsonRequest({}), deps);
  assertEquals(missing.status, 400);

  const blank = await handleRequest(jsonRequest({ prompt: "   " }), deps);
  assertEquals(blank.status, 400);
});

Deno.test("cache hit: HEAD 200 returns the URL without calling the provider", async () => {
  const fake = new FakeFetch();
  fake.headStatus = 200;

  const response = await handleRequest(
    jsonRequest({ prompt: "un templo entre la niebla" }),
    { fetchImpl: fake.fetch, ...baseDeps },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.cached, true);
  assertEquals(typeof body.imageUrl, "string");
  assertEquals(fake.calls.length, 1, "should only HEAD, never call the provider");
  assertEquals(fake.calls[0].method, "HEAD");
});

Deno.test("cache miss: fetches from the provider and uploads to Storage", async () => {
  const fake = new FakeFetch();
  fake.headStatus = 404;

  const response = await handleRequest(
    jsonRequest({ prompt: "un templo entre la niebla" }),
    { fetchImpl: fake.fetch, ...baseDeps },
  );

  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.cached, false);
  assertEquals(typeof body.imageUrl, "string");
  assertEquals(fake.calls.map((c) => c.method), ["HEAD", "GET", "POST"]);
  assertEquals(fake.calls[1].url.includes("image.pollinations.ai"), true);
  assertEquals(fake.calls[2].url.includes("/storage/v1/object/"), true);
});

Deno.test("returns 502 when the image provider fails", async () => {
  const fake = new FakeFetch();
  fake.headStatus = 404;
  fake.providerStatus = 500;

  const response = await handleRequest(
    jsonRequest({ prompt: "algo" }),
    { fetchImpl: fake.fetch, ...baseDeps },
  );
  assertEquals(response.status, 502);
});

Deno.test("returns 502 when the Storage upload fails", async () => {
  const fake = new FakeFetch();
  fake.headStatus = 404;
  fake.uploadStatus = 500;

  const response = await handleRequest(
    jsonRequest({ prompt: "algo" }),
    { fetchImpl: fake.fetch, ...baseDeps },
  );
  assertEquals(response.status, 502);
});

Deno.test("the same prompt maps to the same cached URL (deterministic hash)", async () => {
  const fakeA = new FakeFetch();
  fakeA.headStatus = 200;
  const responseA = await handleRequest(
    jsonRequest({ prompt: "un cultivador sereno" }),
    { fetchImpl: fakeA.fetch, ...baseDeps },
  );

  const fakeB = new FakeFetch();
  fakeB.headStatus = 200;
  const responseB = await handleRequest(
    jsonRequest({ prompt: "un cultivador sereno" }),
    { fetchImpl: fakeB.fetch, ...baseDeps },
  );

  const bodyA = await responseA.json();
  const bodyB = await responseB.json();
  assertEquals(bodyA.imageUrl, bodyB.imageUrl);
});
