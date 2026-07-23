import '../engine/state_delta.dart';
import '../state/character.dart';
import 'gate.dart';

/// An activity offered inside a [StateHubNode] (campaign-bible §9.1, §11.1):
/// a hub gives the player agency by letting them do several things in any
/// order — rest, investigate, talk to an ally — before moving on. Unlike a
/// [StoryChoice], picking an activity doesn't advance the graph.
class HubActivity {
  const HubActivity({
    required this.id,
    required this.label,
    this.gate = const AlwaysGate(),
    this.effects = const [],
    this.repeatable = true,
  });

  final String id;
  final String label;
  final Gate gate;

  /// Deterministic effects applied when this activity is done — validated
  /// through the same `ApplyStateDeltas` as everything else (CLAUDE.md §2.3).
  final List<StateDelta> effects;

  /// Whether this can be done more than once (e.g. "descansar") vs. a
  /// one-time discovery (e.g. "examinar la tablilla"). Enforcing "only
  /// once" is the caller's job (it depends on session/turn history the
  /// activity itself doesn't hold) — this just declares the intent.
  final bool repeatable;

  bool isAvailableTo(Character character) => gate.isSatisfiedBy(character);

  factory HubActivity.fromJson(Map<String, dynamic> json) {
    return HubActivity(
      id: json['id'] as String,
      label: json['label'] as String,
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
      effects: _effectsFromJson(json['effects']),
      repeatable: json['repeatable'] as bool? ?? true,
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
