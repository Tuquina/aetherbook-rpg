import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/narrative/abstract_opponent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AbstractOpponent.guardAfter', () {
    const opponent = AbstractOpponent(
      id: 'coro_blanco',
      displayName: 'Coro Blanco',
      maxGuard: 4,
    );

    test('a success reduces guard by 1', () {
      expect(opponent.guardAfter(4, ActionOutcome.success), 3);
    });

    test('a critical success reduces guard by 2', () {
      expect(opponent.guardAfter(4, ActionOutcome.criticalSuccess), 2);
    });

    test('a failure leaves guard unchanged (the opponent acts instead)', () {
      expect(opponent.guardAfter(4, ActionOutcome.failure), 4);
    });

    test('guard never drops below 0', () {
      expect(opponent.guardAfter(1, ActionOutcome.criticalSuccess), 0);
    });

    test('guard never exceeds maxGuard', () {
      // Defensive: even if something tried to "heal" guard past the max.
      expect(opponent.guardAfter(10, ActionOutcome.failure), 4);
    });
  });

  group('AbstractOpponent.isDefeated', () {
    const opponent = AbstractOpponent(id: 'x', displayName: 'X', maxGuard: 2);

    test('is defeated at 0 guard', () {
      expect(opponent.isDefeated(0), isTrue);
    });

    test('is not defeated above 0 guard', () {
      expect(opponent.isDefeated(1), isFalse);
    });
  });

  group('AbstractOpponent.fromJson', () {
    test('parses the campaign-bible §6.13 opponent shape', () {
      final opponent = AbstractOpponent.fromJson({
        'id': 'coro_blanco',
        'display_name': 'Coro Blanco',
        'guard': 4,
        'typical_damage': 3,
        'nonviolent_alternative': 'Nombrar recuerdos, escuchar, ofrecer qi',
      });
      expect(opponent.id, 'coro_blanco');
      expect(opponent.displayName, 'Coro Blanco');
      expect(opponent.maxGuard, 4);
      expect(opponent.typicalDamage, 3);
      expect(opponent.nonviolentAlternative, 'Nombrar recuerdos, escuchar, ofrecer qi');
    });

    test('defaults display name to id and damage to 0', () {
      final opponent = AbstractOpponent.fromJson({'id': 'x', 'guard': 2});
      expect(opponent.displayName, 'x');
      expect(opponent.typicalDamage, 0);
      expect(opponent.nonviolentAlternative, '');
    });
  });
}
