/// Deterministically maps an action's text to the attribute its check should
/// use (CLAUDE.md §2.2, GDD §4.1): keyword matching declared per world, in
/// code — the AI never decides which attribute a check uses, whether the
/// action came from a suggested choice or from free-typed text.
///
/// Matching is a simple keyword-count vote: for each candidate attribute, count
/// how many of its keywords appear (case-insensitively, substring match) in
/// the action text. The attribute with the most matches wins; ties and no
/// matches fall back to [fallback].
class InferActionAttribute {
  const InferActionAttribute();

  String call({
    required String action,
    required Map<String, List<String>> attributeKeywords,
    required String fallback,
  }) {
    final normalized = action.toLowerCase();

    String? best;
    var bestScore = 0;
    for (final entry in attributeKeywords.entries) {
      final score = entry.value
          .where((keyword) => normalized.contains(keyword.toLowerCase()))
          .length;
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }

    return best ?? fallback;
  }
}
