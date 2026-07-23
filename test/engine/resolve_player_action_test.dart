import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/engine/resolve_player_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResolvePlayerAction', () {
    test('failure when total is below difficulty', () {
      final resolve = ResolvePlayerAction(const FixedDice(5));
      final result = resolve(attributeKey: 'espiritu', attribute: 2, difficulty: 12); // 2 + 5 = 7
      expect(result.outcome, ActionOutcome.failure);
      expect(result.total, 7);
      expect(result.isSuccess, isFalse);
      expect(result.attributeKey, 'espiritu');
    });

    test('success when total reaches difficulty but below critical margin', () {
      final resolve = ResolvePlayerAction(const FixedDice(10));
      // 3 + 10 = 13; difficulty 12; margin 5 -> success (13 < 17).
      final result = resolve(attributeKey: 'espiritu', attribute: 3, difficulty: 12);
      expect(result.outcome, ActionOutcome.success);
      expect(result.isSuccess, isTrue);
    });

    test('critical success when total meets difficulty + margin', () {
      final resolve = ResolvePlayerAction(const FixedDice(15));
      // 4 + 15 = 19; difficulty 12; margin 5 -> 19 >= 17 -> critical.
      final result = resolve(attributeKey: 'espiritu', attribute: 4, difficulty: 12);
      expect(result.outcome, ActionOutcome.criticalSuccess);
    });

    test('natural 20 is always a critical success, even below difficulty', () {
      final resolve = ResolvePlayerAction(const FixedDice(20));
      // 0 + 20 = 20 but difficulty is absurdly high; nat 20 wins anyway.
      final result = resolve(attributeKey: 'espiritu', attribute: 0, difficulty: 100);
      expect(result.outcome, ActionOutcome.criticalSuccess);
      expect(result.isNatural20, isTrue);
    });

    test('natural 1 is always a failure, even above difficulty', () {
      final resolve = ResolvePlayerAction(const FixedDice(1));
      // 50 + 1 = 51 clears difficulty 2, but nat 1 fails regardless.
      final result = resolve(attributeKey: 'espiritu', attribute: 50, difficulty: 2);
      expect(result.outcome, ActionOutcome.failure);
      expect(result.isNatural1, isTrue);
    });

    test('modifiers are added into the total', () {
      final resolve = ResolvePlayerAction(const FixedDice(8));
      // 3 + 2(mod) + 8 = 13 vs 12 -> success.
      final result = resolve(attributeKey: 'espiritu', attribute: 3, difficulty: 12, modifiers: 2);
      expect(result.total, 13);
      expect(result.outcome, ActionOutcome.success);
    });

    test('boundary: exactly at difficulty is a success', () {
      final resolve = ResolvePlayerAction(const FixedDice(9));
      final result = resolve(attributeKey: 'espiritu', attribute: 3, difficulty: 12); // 12 == 12
      expect(result.outcome, ActionOutcome.success);
    });

    test('boundary: exactly at difficulty + margin is a critical', () {
      final resolve = ResolvePlayerAction(const FixedDice(14));
      // 3 + 14 = 17 == 12 + 5 -> critical.
      final result = resolve(attributeKey: 'espiritu', attribute: 3, difficulty: 12);
      expect(result.outcome, ActionOutcome.criticalSuccess);
    });

    test('is deterministic: same dice + inputs -> same result', () {
      final a = ResolvePlayerAction(SequenceDice([7, 12, 3]));
      final b = ResolvePlayerAction(SequenceDice([7, 12, 3]));
      for (var i = 0; i < 3; i++) {
        final ra = a(attributeKey: 'espiritu', attribute: 4, difficulty: 12);
        final rb = b(attributeKey: 'espiritu', attribute: 4, difficulty: 12);
        expect(ra.outcome, rb.outcome);
        expect(ra.total, rb.total);
      }
    });

    test('custom criticalMargin changes the critical threshold', () {
      final resolve = ResolvePlayerAction(const FixedDice(10));
      // 4 + 10 = 14; difficulty 12. margin 2 -> 14 >= 14 -> critical.
      final result = resolve(attributeKey: 'espiritu', attribute: 4, difficulty: 12, criticalMargin: 2);
      expect(result.outcome, ActionOutcome.criticalSuccess);
    });

    test('rejects a criticalMargin below 1', () {
      final resolve = ResolvePlayerAction(const FixedDice(10));
      expect(
        () => resolve(attributeKey: 'espiritu', attribute: 4, difficulty: 12, criticalMargin: 0),
        throwsArgumentError,
      );
    });
  });

  group('ResolvePlayerAction — rollMode (ventaja/desventaja)', () {
    test('advantage keeps the higher of two d20s', () {
      final resolve = ResolvePlayerAction(SequenceDice([8, 17]));
      final result = resolve(
        attributeKey: 'espiritu',
        attribute: 0,
        difficulty: 12,
        rollMode: RollMode.advantage,
      );
      expect(result.roll, 17);
      expect(result.discardedRoll, 8);
      expect(result.rollMode, RollMode.advantage);
    });

    test('disadvantage keeps the lower of two d20s', () {
      final resolve = ResolvePlayerAction(SequenceDice([8, 17]));
      final result = resolve(
        attributeKey: 'espiritu',
        attribute: 0,
        difficulty: 12,
        rollMode: RollMode.disadvantage,
      );
      expect(result.roll, 8);
      expect(result.discardedRoll, 17);
    });

    test('a normal roll never sets a discarded roll', () {
      final resolve = ResolvePlayerAction(const FixedDice(10));
      final result = resolve(attributeKey: 'espiritu', attribute: 0, difficulty: 12);
      expect(result.rollMode, RollMode.normal);
      expect(result.discardedRoll, isNull);
    });

    test('advantage can turn a discarded 1 into a kept natural 20', () {
      final resolve = ResolvePlayerAction(SequenceDice([1, 20]));
      final result = resolve(
        attributeKey: 'espiritu',
        attribute: 0,
        difficulty: 100,
        rollMode: RollMode.advantage,
      );
      expect(result.isNatural20, isTrue);
      expect(result.outcome, ActionOutcome.criticalSuccess);
    });

    test('disadvantage can turn a discarded 20 into a kept natural 1', () {
      final resolve = ResolvePlayerAction(SequenceDice([20, 1]));
      final result = resolve(
        attributeKey: 'espiritu',
        attribute: 50,
        difficulty: 2,
        rollMode: RollMode.disadvantage,
      );
      expect(result.isNatural1, isTrue);
      expect(result.outcome, ActionOutcome.failure);
    });
  });

  group('combineRollModifiers', () {
    test('no sources -> normal', () {
      expect(
        combineRollModifiers(hasAdvantage: false, hasDisadvantage: false),
        RollMode.normal,
      );
    });

    test('advantage only -> advantage', () {
      expect(
        combineRollModifiers(hasAdvantage: true, hasDisadvantage: false),
        RollMode.advantage,
      );
    });

    test('disadvantage only -> disadvantage', () {
      expect(
        combineRollModifiers(hasAdvantage: false, hasDisadvantage: true),
        RollMode.disadvantage,
      );
    });

    test('both present -> they cancel to normal', () {
      expect(
        combineRollModifiers(hasAdvantage: true, hasDisadvantage: true),
        RollMode.normal,
      );
    });
  });
}
