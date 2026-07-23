import '../../core/state/game_session.dart';
import '../../ports/memory_digest_port.dart';

/// Returns a fixed, cheap summary — no network, no quota (CLAUDE.md §9). Lets
/// the three-level memory flow (trigger, persist, travel in the next prompt)
/// be played and tested without spending Groq quota.
class FakeMemoryDigestAdapter implements MemoryDigestPort {
  const FakeMemoryDigestAdapter();

  @override
  Future<String> summarize({
    required List<Turn> turnsToSummarize,
    String? previousDigest,
  }) async {
    final continuation = (previousDigest == null || previousDigest.isEmpty)
        ? ''
        : ' Continuando de: "$previousDigest".';
    return 'Resumen de ${turnsToSummarize.length} turno(s).$continuation';
  }
}
