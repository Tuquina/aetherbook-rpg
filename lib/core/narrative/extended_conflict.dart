/// How an [ExtendedConflict] was decided.
enum ConflictOutcome {
  /// Reached the required number of successes first.
  succeeded,

  /// Reached the allowed number of failures first — the story still moves
  /// forward, but with the node's stated bigger consequence (campaign-bible
  /// §6.12: "también se avanza, pero se aplica la consecuencia mayor").
  failedForward,
}

/// Immutable progress through an [ExtendedConflict]: how many successes and
/// failures so far, and which attribute the most recent attempt used (so the
/// repeat-attribute penalty can be computed for the next one).
class ExtendedConflictProgress {
  const ExtendedConflictProgress({
    this.successes = 0,
    this.failures = 0,
    this.lastAttributeKey,
  });

  final int successes;
  final int failures;
  final String? lastAttributeKey;
}

/// A sequence of checks where reaching [successesRequired] successes
/// completes the objective, and reaching [failuresAllowed] failures also
/// ends it — whichever comes first (campaign-bible §6.12). "Cada enfoque
/// debe ser distinto": repeating the immediately preceding attempt's
/// attribute applies [repeatAttributePenalty] to that attempt.
///
/// Pure and stateless itself — it operates on an [ExtendedConflictProgress]
/// snapshot and returns a new one, the same shape as `RankProgression` or
/// `ApplyStateDeltas`. Tracking *which* progress belongs to *which* active
/// conflict is session state, wired in once a campaign's nodes are loaded.
class ExtendedConflict {
  const ExtendedConflict({
    required this.successesRequired,
    required this.failuresAllowed,
    this.repeatAttributePenalty = -2,
  });

  final int successesRequired;
  final int failuresAllowed;
  final int repeatAttributePenalty;

  /// The situational modifier for an attempt using [attributeKey], given
  /// [progress] — applies only when it repeats the immediately preceding
  /// attempt's attribute.
  int modifierFor(ExtendedConflictProgress progress, String attributeKey) {
    if (progress.lastAttributeKey == attributeKey) return repeatAttributePenalty;
    return 0;
  }

  /// Records one attempt's result and returns the updated progress.
  ExtendedConflictProgress recordAttempt(
    ExtendedConflictProgress progress, {
    required String attributeKey,
    required bool succeeded,
  }) {
    return ExtendedConflictProgress(
      successes: progress.successes + (succeeded ? 1 : 0),
      failures: progress.failures + (succeeded ? 0 : 1),
      lastAttributeKey: attributeKey,
    );
  }

  /// Whether the conflict is decided yet — `null` while still in progress.
  ConflictOutcome? outcomeFor(ExtendedConflictProgress progress) {
    if (progress.successes >= successesRequired) {
      return ConflictOutcome.succeeded;
    }
    if (progress.failures >= failuresAllowed) {
      return ConflictOutcome.failedForward;
    }
    return null;
  }

  factory ExtendedConflict.fromJson(Map<String, dynamic> json) {
    return ExtendedConflict(
      successesRequired: (json['successes_required'] as num).toInt(),
      failuresAllowed: (json['failures_allowed'] as num).toInt(),
      repeatAttributePenalty:
          (json['repeat_attribute_penalty'] as num?)?.toInt() ?? -2,
    );
  }
}
