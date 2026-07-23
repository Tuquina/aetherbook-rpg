import 'package:aetherbook/core/engine/apply_state_deltas.dart';
import 'package:aetherbook/core/engine/rank_progression.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/meter_definition.dart';
import 'package:aetherbook/core/world/rank_definition.dart';
import 'package:aetherbook/core/world/resource_formula.dart';
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

  group('ApplyStateDeltas — resource formulas (campaign-bible "descansar")', () {
    test('caps a resource restore at the character-specific formula ceiling', () {
      final withFormula = const ApplyStateDeltas(
        resourceFormulas: {
          'vitality': ResourceFormula(base: 8, perAttribute: {'cuerpo': 2}),
        },
      );
      // cuerpo 2 -> ceiling 8 + 2*2 = 12.
      final character = base().copyWith(
        attributes: {'espiritu': 2, 'cuerpo': 2},
        resources: {'vitality': 3},
      );
      final result = withFormula(character, [
        const StateDelta(type: StateDeltaType.resource, key: 'vitality', value: 9999),
      ]);
      expect(result.character.resource('vitality'), 12);
    });

    test('a resource with no declared formula keeps the old unbounded-above behavior', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.resource, key: 'qi', value: 9999),
      ]);
      expect(result.character.resource('qi'), 10009);
    });
  });

  group('ApplyStateDeltas — relationship (campaign-bible §8.2/§19.3)', () {
    test('increments a relationship from zero', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.relationship,
          key: 'lian_suyin',
          value: 1,
        ),
      ]);
      expect(result.character.relationship('lian_suyin'), 1);
      expect(result.applied, hasLength(1));
    });

    test('rejects a delta whose magnitude is greater than 1', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.relationship,
          key: 'lian_suyin',
          value: 2,
        ),
      ]);
      expect(result.rejected, hasLength(1));
      expect(result.character.relationship('lian_suyin'), 0);
    });

    test('clamps the stored value to [-2, 3]', () {
      var character = base();
      for (var i = 0; i < 5; i++) {
        character = apply(character, [
          const StateDelta(
            type: StateDeltaType.relationship,
            key: 'qiao_wen',
            value: 1,
          ),
        ]).character;
      }
      expect(character.relationship('qiao_wen'), 3);

      for (var i = 0; i < 5; i++) {
        character = apply(character, [
          const StateDelta(
            type: StateDeltaType.relationship,
            key: 'qiao_wen',
            value: -1,
          ),
        ]).character;
      }
      expect(character.relationship('qiao_wen'), -2);
    });

    test('rejects a non-numeric relationship value', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.relationship,
          key: 'lian_suyin',
          value: 'mucho',
        ),
      ]);
      expect(result.rejected, hasLength(1));
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

  group('ApplyStateDeltas — lists (curated inventory/passenger ids)', () {
    test('listAdd appends an id to a named list', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.listAdd,
          key: 'inventory',
          value: 'llave_maestra_ferroviaria',
        ),
      ]);
      expect(result.character.list('inventory'), ['llave_maestra_ferroviaria']);
    });

    test('listAdd is idempotent — adding the same id twice keeps one copy', () {
      var character = base();
      for (var i = 0; i < 2; i++) {
        character = apply(character, [
          const StateDelta(
            type: StateDeltaType.listAdd,
            key: 'inventory',
            value: 'radio_portatil',
          ),
        ]).character;
      }
      expect(character.list('inventory'), ['radio_portatil']);
    });

    test('listRemove drops an id from a named list, no-op if absent', () {
      final withItem = apply(base(), [
        const StateDelta(
          type: StateDeltaType.listAdd,
          key: 'selected_passengers',
          value: 'abril',
        ),
      ]).character;
      final result = apply(withItem, [
        const StateDelta(
          type: StateDeltaType.listRemove,
          key: 'selected_passengers',
          value: 'abril',
        ),
      ]);
      expect(result.character.list('selected_passengers'), isEmpty);

      final noOp = apply(result.character, [
        const StateDelta(
          type: StateDeltaType.listRemove,
          key: 'selected_passengers',
          value: 'nunca_estuvo',
        ),
      ]);
      expect(noOp.rejected, isEmpty);
      expect(noOp.character.list('selected_passengers'), isEmpty);
    });

    test('rejects a list delta whose value is not a string id', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.listAdd, key: 'inventory', value: 5),
      ]);
      expect(result.rejected, hasLength(1));
    });
  });

  group('ApplyStateDeltas — vars (curated enum/id-like state)', () {
    test('varSet stores a free-form value', () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.varSet,
          key: 'passenger_policy',
          value: 'vulnerables_primero',
        ),
      ]);
      expect(result.character.varValue('passenger_policy'), 'vulnerables_primero');
    });

    test('varSet overwrites a previous value', () {
      final first = apply(base(), [
        const StateDelta(type: StateDeltaType.varSet, key: 'selected_profile_id', value: 'manos_de_taller'),
      ]).character;
      final second = apply(first, [
        const StateDelta(type: StateDeltaType.varSet, key: 'selected_profile_id', value: 'ojos_de_ruta'),
      ]).character;
      expect(second.varValue('selected_profile_id'), 'ojos_de_ruta');
    });

    test('rejects a var delta whose value is not a string', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.varSet, key: 'x', value: true),
      ]);
      expect(result.rejected, hasLength(1));
    });
  });

  group('ApplyStateDeltas — absolute set for meter/resource', () {
    test("operation 'set' replaces a meter outright instead of adding", () {
      final withBounds = const ApplyStateDeltas(
        meterDefinitions: {'hours_remaining': MeterDefinition(min: 0, max: 96)},
      );
      final afterIncrement = withBounds(base(), [
        const StateDelta(type: StateDeltaType.meter, key: 'hours_remaining', value: 90),
      ]).character;
      final result = withBounds(afterIncrement, [
        const StateDelta(
          type: StateDeltaType.meter,
          key: 'hours_remaining',
          value: 8,
          operation: 'set',
        ),
      ]);
      expect(result.character.meter('hours_remaining'), 8);
    });

    test("operation 'set' replaces a resource outright instead of adding", () {
      final result = apply(base(), [
        const StateDelta(
          type: StateDeltaType.resource,
          key: 'qi',
          value: 3,
          operation: 'set',
        ),
      ]);
      expect(result.character.resource('qi'), 3);
    });

    test('omitting operation keeps the default increment behavior', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.resource, key: 'qi', value: 3),
      ]);
      expect(result.character.resource('qi'), 13);
    });
  });

  group('ApplyStateDeltas — configurable relationship bounds (curated worlds)', () {
    test('a curated world can widen the per-delta magnitude cap and stored range', () {
      final wide = const ApplyStateDeltas(
        relationshipMagnitudeCap: 3,
        relationshipMin: -3,
        relationshipMax: 3,
      );
      final result = wide(base(), [
        const StateDelta(type: StateDeltaType.relationship, key: 'abril', value: -3),
      ]);
      expect(result.applied, hasLength(1));
      expect(result.character.relationship('abril'), -3);
    });

    test('the default configuration still rejects a magnitude-2 delta', () {
      final result = apply(base(), [
        const StateDelta(type: StateDeltaType.relationship, key: 'abril', value: -2),
      ]);
      expect(result.rejected, hasLength(1));
    });
  });
}
