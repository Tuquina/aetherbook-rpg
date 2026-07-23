import 'action_resolution.dart';
import 'dice.dart';

/// Resolves a player action deterministically: `attribute + modifiers + d20`
/// against a difficulty, sorted into three bands (CLAUDE.md §2.2, GDD §4.4).
///
/// House rules for the bands:
///  - A natural 20 is **always** a critical success, and a natural 1 is
///    **always** a failure, regardless of totals.
///  - Otherwise: `total >= difficulty + criticalMargin` -> critical success;
///    `total >= difficulty` -> success; else -> failure.
///
/// [rollMode] (campaign-bible §6.5) rolls 2d20 and keeps the higher face
/// (advantage) or the lower one (disadvantage) instead of a single d20; the
/// *kept* face is what natural-20/natural-1 checks look at, exactly as if it
/// had been the only roll. Combining multiple advantage/disadvantage
/// sources into a single [RollMode] is the caller's job — see
/// `combineRollModifiers`.
///
/// Pure and side-effect free: the randomness source is injected, so the same
/// inputs always produce the same result under test.
class ResolvePlayerAction {
  const ResolvePlayerAction(this._dice);

  final Dice _dice;

  ActionResolution call({
    required String attributeKey,
    required int attribute,
    required int difficulty,
    int modifiers = 0,
    int criticalMargin = 5,
    RollMode rollMode = RollMode.normal,
  }) {
    if (criticalMargin < 1) {
      throw ArgumentError.value(
          criticalMargin, 'criticalMargin', 'must be >= 1');
    }

    final (roll, discardedRoll) = _rollFor(rollMode);
    final total = attribute + modifiers + roll;
    final isNatural20 = roll == 20;
    final isNatural1 = roll == 1;

    final ActionOutcome outcome;
    if (isNatural20) {
      outcome = ActionOutcome.criticalSuccess;
    } else if (isNatural1) {
      outcome = ActionOutcome.failure;
    } else if (total >= difficulty + criticalMargin) {
      outcome = ActionOutcome.criticalSuccess;
    } else if (total >= difficulty) {
      outcome = ActionOutcome.success;
    } else {
      outcome = ActionOutcome.failure;
    }

    return ActionResolution(
      outcome: outcome,
      attributeKey: attributeKey,
      attribute: attribute,
      modifiers: modifiers,
      roll: roll,
      difficulty: difficulty,
      total: total,
      isNatural20: isNatural20,
      isNatural1: isNatural1,
      rollMode: rollMode,
      discardedRoll: discardedRoll,
    );
  }

  /// Returns `(kept, discarded)`. For [RollMode.normal], only one d20 is
  /// rolled and there's nothing to discard.
  (int, int?) _rollFor(RollMode mode) {
    if (mode == RollMode.normal) {
      return (_dice.roll(20), null);
    }
    final a = _dice.roll(20);
    final b = _dice.roll(20);
    final keepHigher = mode == RollMode.advantage;
    final kept = keepHigher ? (a > b ? a : b) : (a < b ? a : b);
    final discarded = kept == a ? b : a;
    return (kept, discarded);
  }
}

/// Reduces however many advantage/disadvantage sources apply to a check into
/// the single [RollMode] `ResolvePlayerAction` expects (§6.5): "varias
/// fuentes no se acumulan" (multiple sources of the same kind don't stack
/// into more dice) and "si ambas existen, se cancelan" (advantage and
/// disadvantage together cancel out to a normal roll).
RollMode combineRollModifiers({
  required bool hasAdvantage,
  required bool hasDisadvantage,
}) {
  if (hasAdvantage == hasDisadvantage) return RollMode.normal;
  return hasAdvantage ? RollMode.advantage : RollMode.disadvantage;
}
