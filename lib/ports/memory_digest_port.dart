import '../core/state/game_session.dart';

/// Medium-term memory (CLAUDE.md §6, GDD §5.3): summarizes recent turns into
/// a compact digest (~150 words) that travels in every subsequent narrator
/// prompt, so the model doesn't need the full turn history to keep coherence.
abstract class MemoryDigestPort {
  Future<String> summarize({
    required List<Turn> turnsToSummarize,
    String? previousDigest,
  });
}
