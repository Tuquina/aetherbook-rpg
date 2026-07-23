import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProposedStateDelta.toStateDelta', () {
    test('converts when operation is omitted', () {
      const proposed = ProposedStateDelta(
        type: StateDeltaType.exp,
        key: 'exp',
        value: 10,
      );
      final delta = proposed.toStateDelta();
      expect(delta, isNotNull);
      expect(delta!.type, StateDeltaType.exp);
      expect(delta.value, 10);
    });

    test('converts when operation is "increment"', () {
      const proposed = ProposedStateDelta(
        type: StateDeltaType.relationship,
        key: 'lian_suyin',
        value: 1,
        operation: 'increment',
        reason: 'aceptó un costo',
      );
      expect(proposed.toStateDelta(), isNotNull);
    });

    test('rejects an unsupported declared operation', () {
      const proposed = ProposedStateDelta(
        type: StateDeltaType.resource,
        key: 'qi',
        value: 5,
        operation: 'set',
      );
      expect(proposed.toStateDelta(), isNull);
    });
  });

  group('StateDelta.typeFromString', () {
    test('maps "relationship" to StateDeltaType.relationship', () {
      expect(
        StateDelta.typeFromString('relationship'),
        StateDeltaType.relationship,
      );
    });

    test('maps "list_add"/"list_remove"/"var_set" to their curated types', () {
      expect(StateDelta.typeFromString('list_add'), StateDeltaType.listAdd);
      expect(StateDelta.typeFromString('list_remove'), StateDeltaType.listRemove);
      expect(StateDelta.typeFromString('var_set'), StateDeltaType.varSet);
    });

    test('maps an unrecognized string to unknown', () {
      expect(StateDelta.typeFromString('teleport'), StateDeltaType.unknown);
    });
  });

  group('StateDelta.operation', () {
    test('carries an explicit operation (e.g. curated "set")', () {
      const delta = StateDelta(
        type: StateDeltaType.meter,
        key: 'hours_remaining',
        value: 8,
        operation: 'set',
      );
      expect(delta.operation, 'set');
    });

    test('defaults operation to null (increment)', () {
      const delta = StateDelta(type: StateDeltaType.meter, key: 'noise', value: 1);
      expect(delta.operation, isNull);
    });
  });
}
