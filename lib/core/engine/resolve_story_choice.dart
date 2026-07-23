import '../narrative/checkable.dart';
import '../narrative/extended_conflict.dart';
import '../narrative/story_choice.dart';
import '../state/character.dart';
import 'action_resolution.dart';
import 'resolve_player_action.dart';

/// Result of resolving one [Checkable] (a `StoryChoice` or a `HubActivity` —
/// both share the same check/outcome shape): the roll (if any), the outcome
/// branch it resolved to, and — when the node has an [ExtendedConflict] —
/// whether the story is ready to move on yet.
class StoryChoiceResolution {
  const StoryChoiceResolution({
    this.actionResolution,
    required this.outcome,
    this.updatedConflictProgress,
    required this.advances,
  });

  /// `null` when [StoryChoice.requiresCheck] was `false` — an unconditional
  /// choice never rolls.
  final ActionResolution? actionResolution;

  final ChoiceOutcome outcome;

  /// The extended conflict's progress after this attempt, or `null` when the
  /// node has no [ExtendedConflict] at all.
  final ExtendedConflictProgress? updatedConflictProgress;

  /// Whether the story should actually move to [outcome]'s target node now.
  /// Always `true` outside an extended conflict; `false` while one is still
  /// undecided (campaign-bible §6.12: the same approaches keep being offered
  /// until the required successes or failures are reached).
  final bool advances;
}

/// Resolves a single [Checkable] (`StoryChoice` or `HubActivity`) attempt:
/// rolls its own check (own attribute, own difficulty — never
/// `world.defaultDifficulty`), picks the resulting [ChoiceOutcome], and —
/// when the node is mid [ExtendedConflict] — folds the attempt into that
/// conflict's progress to decide whether the scene is actually resolved yet.
///
/// Pure and side-effect free: no `Character` mutation, no session state.
/// `GameController` (Fase 8) applies [StoryChoiceResolution.outcome]'s
/// effects and decides whether to advance `currentNodeId`.
class ResolveStoryChoice {
  const ResolveStoryChoice(this._resolve);

  final ResolvePlayerAction _resolve;

  StoryChoiceResolution call({
    required Checkable choice,
    required Character character,
    ExtendedConflict? extendedConflict,
    ExtendedConflictProgress conflictProgress = const ExtendedConflictProgress(),
  }) {
    ActionResolution? resolution;
    final ActionOutcome outcome;

    if (choice.requiresCheck) {
      final attributeKey = choice.checkAttribute!;
      final modifier = extendedConflict != null
          ? extendedConflict.modifierFor(conflictProgress, attributeKey)
          : 0;
      final rollMode = combineRollModifiers(
        hasAdvantage: choice.advantageWhen?.isSatisfiedBy(character) ?? false,
        hasDisadvantage: choice.disadvantageWhen?.isSatisfiedBy(character) ?? false,
      );
      resolution = _resolve(
        attributeKey: attributeKey,
        attribute: character.attribute(attributeKey),
        difficulty: choice.checkDifficulty!,
        modifiers: modifier,
        rollMode: rollMode,
      );
      outcome = resolution.outcome;
    } else {
      // An unconditional choice always resolves as if it succeeded, so
      // outcomeFor picks onSuccess (or the base target/effects) exactly as
      // it did before checks existed at all.
      outcome = ActionOutcome.success;
    }

    final resolvedOutcome = choice.outcomeFor(outcome);

    ExtendedConflictProgress? updatedProgress;
    var advances = true;
    if (extendedConflict != null) {
      updatedProgress = extendedConflict.recordAttempt(
        conflictProgress,
        attributeKey: choice.checkAttribute ?? '',
        succeeded: resolution?.isSuccess ?? true,
      );
      advances = extendedConflict.outcomeFor(updatedProgress) != null;
    }

    return StoryChoiceResolution(
      actionResolution: resolution,
      outcome: resolvedOutcome,
      updatedConflictProgress: updatedProgress,
      advances: advances,
    );
  }
}
