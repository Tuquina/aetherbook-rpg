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
  }) {
    if (criticalMargin < 1) {
      throw ArgumentError.value(
          criticalMargin, 'criticalMargin', 'must be >= 1');
    }

    final roll = _dice.roll(20);
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
    );
  }
}
