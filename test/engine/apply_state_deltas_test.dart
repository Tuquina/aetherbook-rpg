import 'package:aetherbook/core/engine/apply_state_deltas.dart';
import 'package:aetherbook/core/engine/rank_progression.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/meter_definition.dart';
import 'package:aetherbook/core/world/rank_definition.dart';
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

  group('ApplyStateDeltas — meter (campaign-bible named counters)', () {
    test('applies a meter delta with no declared bounds', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.meter, key: 'ledger_debt', value: 1),
      ]);
      expect(result.character.meter('ledger_debt'), 1);
      expect(result.applied, hasLength(1));
    });

    test('clamps a bounded meter to its declared range (e.g. karma -3..3)', () {
      final withBounds = const ApplyStateDeltas(
        meterDefinitions: {'karma': MeterDefinition(min: -3, max: 3)},
      );
      final result = withBounds(base(), [
        const StateDelta(type: StateDeltaType.meter, key: 'karma', value: 10),
      ]);
      expect(result.character.meter('karma'), 3);
    });

    test('rejects a delta targeting a derived meter (e.g. evidence_count)', () {
      final withDerived = const ApplyStateDeltas(
        meterDefinitions: {
          'evidence_count': MeterDefinition(derivedFromFlags: ['evidence_a']),
        },
      );
      final result = withDerived(base(), [
        const StateDelta(
          type: StateDeltaType.meter,
          key: 'evidence_count',
          value: 1,
        ),
      ]);
      expect(result.rejected, hasLength(1));
      expect(result.character.meter('evidence_count'), 0);
    });

    test('syncs a derived meter onto the character when its flags change', () {
      final withDerived = const ApplyStateDeltas(
        meterDefinitions: {
          'evidence_count': MeterDefinition(
            derivedFromFlags: ['evidence_a', 'evidence_b'],
          ),
        },
      );
      final result = withDerived(base(), [
        const StateDelta(type: StateDeltaType.flag, key: 'evidence_a', value: true),
      ]);
      // Gate.MinMeterGate reads this directly off the character — no World
      // needed — precisely because this sync keeps it correct.
      expect(result.character.meter('evidence_count'), 1);
    });

    test('a derived meter stays in sync across turns as more flags land', () {
      final withDerived = const ApplyStateDeltas(
        meterDefinitions: {
          'evidence_count': MeterDefinition(
            derivedFromFlags: ['evidence_a', 'evidence_b'],
          ),
        },
      );
      final afterFirst = withDerived(base(), [
        const StateDelta(type: StateDeltaType.flag, key: 'evidence_a', value: true),
      ]).character;
      final afterSecond = withDerived(afterFirst, [
        const StateDelta(type: StateDeltaType.flag, key: 'evidence_b', value: true),
      ]).character;
      expect(afterSecond.meter('evidence_count'), 2);
    });

    test('rejects a meter delta with a non-numeric value', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.meter,
          key: 'ledger_debt',
          value: 'mucho',
        ),
      ]);
      expect(result.rejected, hasLength(1));
    });

    test('meter deltas accumulate across turns', () {
      final withBounds = const ApplyStateDeltas(
        meterDefinitions: {'celestial_pressure': MeterDefinition(min: 0, max: 6)},
      );
      var character = base();
      for (var i = 0; i < 3; i++) {
        character = withBounds(character, [
          const StateDelta(
            type: StateDeltaType.meter,
            key: 'celestial_pressure',
            value: 1,
          ),
        ]).character;
      }
      expect(character.meter('celestial_pressure'), 3);
    });
  });

  group('ApplyStateDeltas — rankProgression (milestone-gated ranks)', () {
    const ranks = [
      RankDefinition(id: 'aliento_velado', level: 1, expRequired: 0),
      RankDefinition(
        id: 'meridiano_abierto',
        level: 2,
        expRequired: 5,
        milestoneFlag: 'reached_casa_de_tinta',
      ),
    ];
    final withRanks =
        const ApplyStateDeltas(rankProgression: RankProgression(ranks));

    test('exp accumulates as a running total but does not promote without the milestone', () {
      final result = withRanks(base(), [
        const StateDelta(type: StateDeltaType.exp, key: 'exp', value: 8),
      ]);
      expect(result.character.exp, 8);
      expect(result.character.level, 1);
    });

    test('promotes when the milestone flag and EXP delta land in the same turn', () {
      final result = withRanks(base(), [
        const StateDelta(type: StateDeltaType.exp, key: 'exp', value: 8),
        const StateDelta(
          type: StateDeltaType.flag,
          key: 'reached_casa_de_tinta',
          value: true,
        ),
      ]);
      expect(result.character.level, 2);
      expect(result.character.exp, 8);
    });

    test('a flag-only turn (no exp delta) still promotes banked EXP from earlier turns', () {
      // Turn 1: bank enough EXP, milestone not reached yet.
      final afterExp = withRanks(base(), [
        const StateDelta(type: StateDeltaType.exp, key: 'exp', value: 8),
      ]).character;
      expect(afterExp.level, 1);

      // Turn 2: only a flag delta — no exp delta in this batch at all.
      final afterMilestone = withRanks(afterExp, [
        const StateDelta(
          type: StateDeltaType.flag,
          key: 'reached_casa_de_tinta',
          value: true,
        ),
      ]).character;
      expect(afterMilestone.level, 2);
      expect(afterMilestone.exp, 8);
    });

    test('without a configured rankProgression, exp uses the simple linear progression as before', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.flag,
          key: 'reached_casa_de_tinta',
          value: true,
        ),
      ]);
      // No rankProgression -> the final re-check step is skipped entirely;
      // a bare flag delta never touches level/exp.
      expect(result.character.level, 1);
      expect(result.character.exp, 0);
    });
  });
}
