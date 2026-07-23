import '../engine/action_resolution.dart';
import '../engine/state_delta.dart';
import '../state/character.dart';
import 'checkable.dart';
import 'gate.dart';

/// The effects/destination a checked [StoryChoice] or `HubActivity` resolves
/// to for one outcome band (campaign-bible: most curated choices tie a
/// check's success/failure to different consequences, sometimes even a
/// different destination node — e.g. "empujar la tapa": success leaves
/// through control, failure capsizes the boat).
class ChoiceOutcome {
  const ChoiceOutcome({this.targetNodeId, this.effects = const [], this.resultText});

  /// Overrides the choice's own target node for this outcome. `null` means
  /// "use the choice's own `targetNodeId`" (most outcomes don't redirect
  /// anywhere new, they just add a cost or a different flag).
  final String? targetNodeId;
  final List<StateDelta> effects;

  /// Fully authored prose for this exact outcome band (a curated campaign's
  /// `copy_key`, already resolved to a literal string in the JSON — see
  /// campaign-bible §25.4/§25.8). When set, `GameController` can render this
  /// turn without ever calling `NarratorPort` (a world declaring
  /// `ai_runtime_required: false` requires every reachable outcome to carry
  /// one — enforced by content tests, not by a runtime AI fallback). `null`
  /// for hybrid/freeform content, where the AI narrator still dresses the
  /// outcome.
  final String? resultText;

  factory ChoiceOutcome.fromJson(Map<String, dynamic> json) {
    return ChoiceOutcome(
      targetNodeId: json['target'] as String?,
      effects: _effectsFromJson(json['effects']),
      resultText: json['result_text'] as String?,
    );
  }
}

/// A fixed, authored edge out of a [StoryNode] (GDD §4.1). Distinct from a
/// freeform action: the target node and effects are known ahead of time by
/// the content author, not proposed by the AI at play time.
///
/// Optionally ties to a check (campaign-bible §6.1-6.4): when
/// [checkAttribute]/[checkDifficulty] are set, the choice isn't a plain
/// unconditional edge — resolving it means rolling that check first and then
/// picking the [ChoiceOutcome] for the resulting [ActionOutcome] via
/// [outcomeFor]. `null` on either field (the default) preserves the original,
/// unconditional behavior exactly. Actually performing the roll and applying
/// the chosen outcome is the caller's job (`GameController`, Fase 8) — this
/// class only holds the data and the pure fallback-resolution logic.
class StoryChoice implements Checkable {
  const StoryChoice({
    required this.label,
    required this.targetNodeId,
    this.gate = const AlwaysGate(),
    this.effects = const [],
    this.resultText,
    this.checkAttribute,
    this.checkDifficulty,
    this.onSuccess,
    this.onCriticalSuccess,
    this.onFailure,
    this.requiresConfirmation = false,
    this.confirmationText,
    this.advantageWhen,
    this.disadvantageWhen,
  });

  final String label;
  final String targetNodeId;
  final Gate gate;

  /// Deterministic effects applied when this choice is taken and no check is
  /// involved (or as the fallback for an outcome with no dedicated
  /// [ChoiceOutcome]) — still validated through [ApplyStateDeltas] the same
  /// as AI-proposed deltas (CLAUDE.md §2.3).
  final List<StateDelta> effects;

  /// Authored prose for an **unconditional** choice (no check at all) — the
  /// top-level twin of `ChoiceOutcome.resultText`, folded into the `base`
  /// outcome [outcomeFor] falls back to. A checked choice's text lives on
  /// its `onSuccess`/`onFailure`/`onCriticalSuccess` branches instead.
  final String? resultText;

  /// Which attribute this choice's check uses, or `null` for no check at all
  /// (an unconditional choice, or one resolved "for free" by an already-met
  /// gate — campaign-bible's "no se tira si posee X").
  @override
  final String? checkAttribute;

  /// The literal difficulty for this choice's check (9/12/15/18/21 per
  /// campaign-bible §6.3), or `null` when [checkAttribute] is also `null`.
  @override
  final int? checkDifficulty;

  final ChoiceOutcome? onSuccess;

  /// Falls back to [onSuccess] when unset — most choices don't need a
  /// separate critical branch.
  final ChoiceOutcome? onCriticalSuccess;

  /// Falls back to this choice's own [targetNodeId]/[effects] when unset —
  /// most choices' failure is just "no extra cost", not a distinct branch.
  final ChoiceOutcome? onFailure;

  /// Whether taking this choice must be confirmed by the player before it
  /// resolves (campaign-bible §20.3/§26.4: irreversible choices — killing
  /// someone, using a body as a lure, boarding while infected...). The UI
  /// shows [confirmationText] and requires an explicit "yes" first.
  final bool requiresConfirmation;
  final String? confirmationText;

  @override
  final Gate? advantageWhen;

  @override
  final Gate? disadvantageWhen;

  bool isAvailableTo(Character character) => gate.isSatisfiedBy(character);

  /// Whether taking this choice requires rolling a check at all.
  @override
  bool get requiresCheck => checkAttribute != null;

  /// The [ChoiceOutcome] this choice resolves to for [outcome], falling back
  /// through `onCriticalSuccess -> onSuccess -> (targetNodeId, effects)` and
  /// `onFailure -> (targetNodeId, effects)` as documented per field.
  @override
  ChoiceOutcome outcomeFor(ActionOutcome outcome) {
    final base = ChoiceOutcome(
      targetNodeId: targetNodeId,
      effects: effects,
      resultText: resultText,
    );
    return switch (outcome) {
      ActionOutcome.criticalSuccess => onCriticalSuccess ?? onSuccess ?? base,
      ActionOutcome.success => onSuccess ?? base,
      ActionOutcome.failure => onFailure ?? base,
    };
  }

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      label: json['label'] as String,
      targetNodeId: json['target'] as String,
      gate: Gate.fromJson((json['gate'] as Map?)?.cast<String, dynamic>()),
      effects: _effectsFromJson(json['effects']),
      resultText: json['result_text'] as String?,
      checkAttribute: json['check_attribute'] as String?,
      checkDifficulty: (json['check_difficulty'] as num?)?.toInt(),
      onSuccess: _outcomeFromJson(json['on_success']),
      onCriticalSuccess: _outcomeFromJson(json['on_critical_success']),
      onFailure: _outcomeFromJson(json['on_failure']),
      requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
      confirmationText: json['confirmation_text'] as String?,
      advantageWhen: json['advantage_when'] is Map
          ? Gate.fromJson((json['advantage_when'] as Map).cast<String, dynamic>())
          : null,
      disadvantageWhen: json['disadvantage_when'] is Map
          ? Gate.fromJson((json['disadvantage_when'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  static ChoiceOutcome? _outcomeFromJson(Object? value) {
    if (value is! Map) return null;
    return ChoiceOutcome.fromJson(value.cast<String, dynamic>());
  }
}

List<StateDelta> _effectsFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      StateDelta(
        type: StateDelta.typeFromString((item as Map)['type'] as String),
        key: item['key'] as String,
        value: item['value'],
        operation: item['operation'] as String?,
      ),
  ];
}
