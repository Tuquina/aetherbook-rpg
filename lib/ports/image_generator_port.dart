/// Generates a scene illustration for a turn (GDD §6/§7.2). Deliberately
/// different contract from [NarratorPort]/`MemoryDigestPort`: this is a
/// "nice to have", never part of the core loop, so the port itself must
/// never throw — a `null` result just means no image this turn (provider
/// hiccup, timeout, whatever), and the story keeps going exactly as if this
/// port didn't exist.
abstract class ImageGeneratorPort {
  /// [prompt] is the final, already-styled prompt (world's
  /// `image_style_suffix` already appended by the caller — CLAUDE.md:
  /// formatting is a client/adapter concern, not left for the AI to repeat
  /// correctly every time). Returns the image's URL, or `null` if none
  /// could be produced.
  Future<String?> generateImage(String prompt);
}
