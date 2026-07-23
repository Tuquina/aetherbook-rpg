/// The vector a free-typed action gets classified into before it ever
/// reaches an engine mechanic (campaign-bible §18.7). The AI narrator
/// interprets prose, but *this* shape is what the engine actually consumes —
/// same spirit as `ActionResolution`: by the time anything downstream sees
/// it, the classification is already decided in code, not by the model.
enum ActionIntent {
  force,
  evade,
  investigate,
  attune,
  persuade,
  deceive,
  protect,
  useItem,
  useTechnique,
  withdraw,
  impossible;

  static ActionIntent? fromWire(String? raw) {
    if (raw == null) return null;
    for (final value in ActionIntent.values) {
      if (value.wireName == raw) return value;
    }
    return null;
  }

  /// The snake_case name used on the wire (campaign-bible §18.7), e.g.
  /// `useItem` -> `use_item`.
  String get wireName => switch (this) {
        ActionIntent.force => 'force',
        ActionIntent.evade => 'evade',
        ActionIntent.investigate => 'investigate',
        ActionIntent.attune => 'attune',
        ActionIntent.persuade => 'persuade',
        ActionIntent.deceive => 'deceive',
        ActionIntent.protect => 'protect',
        ActionIntent.useItem => 'use_item',
        ActionIntent.useTechnique => 'use_technique',
        ActionIntent.withdraw => 'withdraw',
        ActionIntent.impossible => 'impossible',
      };
}

/// How risky a classified action is, mapped later (by content, per node) to
/// an actual difficulty (campaign-bible §18.7: "mapear riesgo a DC del
/// nodo") — this enum itself never carries a number.
enum RiskLevel {
  none,
  low,
  standard,
  high,
  extreme;

  static RiskLevel fromWire(String? raw) {
    for (final value in RiskLevel.values) {
      if (value.name == raw) return value;
    }
    return RiskLevel.standard;
  }
}

/// Whether a free action fits the campaign's canon as typed, needs to be
/// reframed into the closest viable version, or is impossible within the
/// fiction (campaign-bible §18.7).
enum CanonCompatibility { valid, needsReframing, invalid }

/// The result of classifying a free-typed action (campaign-bible §18.7).
/// Pure data — [ClassifyFreeAction] is what produces it deterministically.
class FreeActionClassification {
  const FreeActionClassification({
    required this.intent,
    required this.attributeKey,
    required this.risk,
    required this.canonCompatibility,
    this.targetId,
  });

  final ActionIntent intent;

  /// Which attribute the resulting check should use, or `'none'` when the
  /// action needs no check (decided the same way as `InferActionAttribute`).
  final String attributeKey;

  /// A known NPC/object id the action refers to, or `null` when none is
  /// recognised.
  final String? targetId;

  final RiskLevel risk;
  final CanonCompatibility canonCompatibility;
}
