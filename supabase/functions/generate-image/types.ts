// Contract for the image-generation Edge Function (GDD §6/§7.2). Small and
// separate from the narrator's own types.ts — different concern entirely
// (an opaque prompt in, a cached URL out), not narration.

/** Body sent by the Dart client's HttpImageGeneratorAdapter. */
export interface GenerateImageRequest {
  /** The final prompt, already including the world's `image_style_suffix`
   * (added client-side — CLAUDE.md: mechanics/formatting in code, not left
   * for the AI to remember to repeat). */
  prompt: string;
}

export interface GenerateImageResponse {
  imageUrl: string;
  /** Whether this was already in Storage (no call to the image provider). */
  cached: boolean;
}
