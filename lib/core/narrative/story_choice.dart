import '../engine/state_delta.dart';
import '../state/character.dart';
import 'gate.dart';

/// A fixed, authored edge out of a [StoryNode] (GDD §4.1). Distinct from a
/// freeform action: the target node and effects are known ahead of time by
/// the content author, not proposed by the AI at play time.
class StoryChoice {
  const StoryChoice({
    required this.label,
    required this.targetNodeId,
    this.gate = const AlwaysGate(),
    this.effects = const [],
  });

  final String label;
  final String targetNodeId;
  final Gate gate;

  /// Deterministic effects applied when this choice is taken — validated
  /// through the same [ApplyStateDeltas] used for AI-proposed deltas
  /// (CLAUDE.md §2.3): the state manda regardless of who authored the change.
  final List<StateDelta> effects;

  bool isAvailableTo(Character character) => gate.isSatisfiedBy(character);

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      label: json['label'] as String,
      targetNodeId: json['target'] as String,
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
      effects: _effectsFromJson(json['effects']),
    );
  }

  static List<StateDelta> _effectsFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        StateDelta(
          type: StateDelta.typeFromString((item as Map)['type'] as String),
          key: item['key'] as String,
          value: item['value'],
        ),
    ];
  }
}
