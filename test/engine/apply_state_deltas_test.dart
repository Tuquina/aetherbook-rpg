import 'package:aetherbook/core/engine/apply_state_deltas.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Character base() => const Character(
        name: 'Discípulo',
        level: 1,
        exp: 0,
        attributes: {'espiritu': 2},
        resources: {'qi': 10},
      );

  const apply = ApplyStateDeltas();

  group('ApplyStateDeltas', () {
    test('applies a valid flag delta', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.flag,
          key: 'conocio_al_anciano',
          value: true,
        ),
      ]);
      expect(result.character.flag('conocio_al_anciano'), isTrue);
      expect(result.applied, hasLength(1));
      expect(result.rejected, isEmpty);
    });

    test('applies exp and levels up via progression', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.exp, key: 'exp', value: 300),
      ]);
      expect(result.character.level, 2);
      expect(result.character.exp, 0);
    });

    test('applies a resource delta and clamps at zero', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.resource, key: 'qi', value: -50),
      ]);
      expect(result.character.resource('qi'), 0);
    });

    test('rejects a flag delta whose value is not a bool', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.flag,
          key: 'roto',
          value: 'sí',
        ),
      ]);
      expect(result.applied, isEmpty);
      expect(result.rejected, hasLength(1));
      expect(result.character.flags.containsKey('roto'), isFalse);
    });

    test('rejects negative exp (state is authoritative, AI only proposes)', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.exp, key: 'exp', value: -999),
      ]);
      expect(result.rejected, hasLength(1));
      expect(result.character.exp, 0);
      expect(result.character.level, 1);
    });

    test('rejects unknown delta types', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.unknown,
          key: 'nivel',
          value: 99,
        ),
      ]);
      expect(result.rejected, hasLength(1));
      expect(result.character.level, 1);
    });

    test('applies valid deltas and rejects invalid ones in one batch', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.exp, key: 'exp', value: 120),
        const StateDelta(type: StateDeltaType.flag, key: 'x', value: 'nope'),
        const StateDelta(type: StateDeltaType.resource, key: 'qi', value: 5),
      ]);
      expect(result.applied, hasLength(2));
      expect(result.rejected, hasLength(1));
      expect(result.character.exp, 120);
      expect(result.character.resource('qi'), 15);
    });
  });
}
