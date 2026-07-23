import '../engine/action_resolution.dart';
import '../engine/state_delta.dart';
import '../state/character.dart';
import 'checkable.dart';
import 'gate.dart';
import 'story_choice.dart' show ChoiceOutcome;

/// An activity offered inside a [StateHubNode] (campaign-bible §9.1, §11.1):
/// a hub gives the player agency by letting them do several things in any
/// order — rest, investigate, talk to an ally — before moving on. Unlike a
/// [StoryChoice], picking an activity doesn't advance the graph.
///
/// Optionally ties to a check, mirroring [StoryChoice] exactly (same fields,
/// same [outcomeFor] fallback logic) — duplicated rather than shared because
/// there are only these two call sites and the codebase prefers a few
/// repeated lines over a premature shared abstraction.
class HubActivity implements Checkable {
  const HubActivity({
    required this.id,
    required this.label,
    this.gate = const AlwaysGate(),
    this.effects = const [],
    this.repeatable = true,
    this.checkAttribute,
    this.checkDifficulty,
    this.onSuccess,
    this.onCriticalSuccess,
    this.onFailure,
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

  /// Which attribute this activity's check uses, or `null` for no check
  /// (either it's unconditional, or it's authored as a separate, always-free
  /// activity alongside a checked one — campaign-bible's "requirement: X o
  /// tirada de Y" pattern, modeled as two `HubActivity` entries rather than
  /// a single conditional one).
  @override
  final String? checkAttribute;

  /// The literal difficulty for this activity's check, or `null` when
  /// [checkAttribute] is also `null`.
  @override
  final int? checkDifficulty;

  final ChoiceOutcome? onSuccess;

  /// Falls back to [onSuccess] when unset.
  final ChoiceOutcome? onCriticalSuccess;

  /// Falls back to this activity's own [effects] (no target node — a hub
  /// activity never advances the graph) when unset.
  final ChoiceOutcome? onFailure;

  bool isAvailableTo(Character character) => gate.isSatisfiedBy(character);

  @override
  bool get requiresCheck => checkAttribute != null;

  /// The [ChoiceOutcome] this activity resolves to for [outcome] — same
  /// fallback chain as `StoryChoice.outcomeFor`. The fallback base carries no
  /// `targetNodeId` since an activity never advances the graph.
  @override
  ChoiceOutcome outcomeFor(ActionOutcome outcome) {
    final base = ChoiceOutcome(effects: effects);
    return switch (outcome) {
      ActionOutcome.criticalSuccess => onCriticalSuccess ?? onSuccess ?? base,
      ActionOutcome.success => onSuccess ?? base,
      ActionOutcome.failure => onFailure ?? base,
    };
  }

  factory HubActivity.fromJson(Map<String, dynamic> json) {
    return HubActivity(
      id: json['id'] as String,
      label: json['label'] as String,
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
      effects: _effectsFromJson(json['effects']),
      repeatable: json['repeatable'] as bool? ?? true,
      checkAttribute: json['check_attribute'] as String?,
      checkDifficulty: (json['check_difficulty'] as num?)?.toInt(),
      onSuccess: _outcomeFromJson(json['on_success']),
      onCriticalSuccess: _outcomeFromJson(json['on_critical_success']),
      onFailure: _outcomeFromJson(json['on_failure']),
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

  static ChoiceOutcome? _outcomeFromJson(Object? value) {
    if (value is! Map) return null;
    return ChoiceOutcome.fromJson(value.cast<String, dynamic>());
  }
}
