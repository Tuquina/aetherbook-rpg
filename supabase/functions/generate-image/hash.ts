// Deterministic filename for the image cache (GDD §6: "mismo prompt ->
// misma imagen, guardada en Supabase Storage"). SHA-256 over the exact
// prompt text, hex-encoded — the same prompt always maps to the same
// Storage object, so a repeated scene never re-hits the image provider.
// Uses Deno's native Web Crypto (crypto.subtle), no extra dependency.
export async function sha256Hex(text: string): Promise<string> {
  const data = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
