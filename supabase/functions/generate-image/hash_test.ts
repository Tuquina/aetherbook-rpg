import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { sha256Hex } from "./hash.ts";

Deno.test("sha256Hex is deterministic: same text -> same hash every time", async () => {
  const a = await sha256Hex("un cultivador sereno bajo la niebla dorada");
  const b = await sha256Hex("un cultivador sereno bajo la niebla dorada");
  assertEquals(a, b);
});

Deno.test("sha256Hex differs for different text", async () => {
  const a = await sha256Hex("prompt uno");
  const b = await sha256Hex("prompt dos");
  assertNotEquals(a, b);
});

Deno.test("sha256Hex returns 64 lowercase hex characters", async () => {
  const hash = await sha256Hex("cualquier cosa");
  assertEquals(hash.length, 64);
  assertEquals(/^[0-9a-f]+$/.test(hash), true);
});
