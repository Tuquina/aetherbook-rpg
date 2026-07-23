import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

Character _character({
  int level = 1,
  Map<String, int> attributes = const {},
  Map<String, int> resources = const {},
  Map<String, bool> flags = const {},
  Map<String, int> meters = const {},
  Map<String, int> relationships = const {},
}) {
  return Character(
    name: 'Discípulo',
    level: level,
    exp: 0,
    attributes: attributes,
    resources: resources,
    flags: flags,
    meters: meters,
    relationships: relationships,
  );
}

void main() {
  group('AlwaysGate', () {
    test('is always satisfied', () {
      expect(const AlwaysGate().isSatisfiedBy(_character()), isTrue);
    });

    test('Gate.fromJson(null) returns AlwaysGate', () {
      expect(Gate.fromJson(null), isA<AlwaysGate>());
    });
  });

  group('FlagGate', () {
    test('satisfied when the flag matches the expected value (default true)', () {
      const gate = FlagGate('conoció_al_anciano');
      expect(gate.isSatisfiedBy(_character(flags: {'conoció_al_anciano': true})), isTrue);
      expect(gate.isSatisfiedBy(_character()), isFalse);
    });

    test('supports requiring a flag to be false', () {
      const gate = FlagGate('traicionó_al_maestro', false);
      expect(gate.isSatisfiedBy(_character()), isTrue);
      expect(
        gate.isSatisfiedBy(_character(flags: {'traicionó_al_maestro': true})),
        isFalse,
      );
    });
  });

  group('MinLevelGate', () {
    test('satisfied at or above the minimum level', () {
      const gate = MinLevelGate(3);
      expect(gate.isSatisfiedBy(_character(level: 2)), isFalse);
      expect(gate.isSatisfiedBy(_character(level: 3)), isTrue);
      expect(gate.isSatisfiedBy(_character(level: 4)), isTrue);
    });
  });

  group('MinAttributeGate / MinResourceGate', () {
    test('attribute gate checks the named attribute', () {
      const gate = MinAttributeGate('espiritu', 5);
      expect(gate.isSatisfiedBy(_character(attributes: {'espiritu': 4})), isFalse);
      expect(gate.isSatisfiedBy(_character(attributes: {'espiritu': 5})), isTrue);
    });

    test('resource gate checks the named resource', () {
      const gate = MinResourceGate('qi', 10);
      expect(gate.isSatisfiedBy(_character(resources: {'qi': 9})), isFalse);
      expect(gate.isSatisfiedBy(_character(resources: {'qi': 10})), isTrue);
    });

    test('meter gate checks the named meter (e.g. evidence_count)', () {
      const gate = MinMeterGate('evidence_count', 3);
      expect(gate.isSatisfiedBy(_character(meters: {'evidence_count': 2})), isFalse);
      expect(gate.isSatisfiedBy(_character(meters: {'evidence_count': 3})), isTrue);
    });
  });

  group('MaxMeterGate', () {
    test('satisfied when the meter is at or below the ceiling (e.g. Infección < 3)', () {
      const gate = MaxMeterGate('infection', 2);
      expect(gate.isSatisfiedBy(_character(meters: {'infection': 2})), isTrue);
      expect(gate.isSatisfiedBy(_character(meters: {'infection': 3})), isFalse);
    });

    test('Gate.fromJson picks MaxMeterGate when the JSON declares "max"', () {
      final gate = Gate.fromJson({'type': 'meter', 'key': 'infection', 'max': 2});
      expect(gate, isA<MaxMeterGate>());
      expect(gate.isSatisfiedBy(_character(meters: {'infection': 1})), isTrue);
      expect(gate.isSatisfiedBy(_character(meters: {'infection': 3})), isFalse);
    });

    test('Gate.fromJson still picks MinMeterGate when the JSON declares "min"', () {
      final gate = Gate.fromJson({'type': 'meter', 'key': 'infection', 'min': 2});
      expect(gate, isA<MinMeterGate>());
    });
  });

  group('VarGate', () {
    test('satisfied when the named var equals the expected string', () {
      const gate = VarGate('origin_id', 'manos_de_taller');
      final character = Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: const {},
        resources: const {},
        vars: const {'origin_id': 'manos_de_taller'},
      );
      expect(gate.isSatisfiedBy(character), isTrue);
      expect(gate.isSatisfiedBy(_character()), isFalse);
    });

    test('Gate.fromJson parses the var shape', () {
      final gate = Gate.fromJson({'type': 'var', 'key': 'passenger_policy', 'equals': 'vulnerables_primero'});
      expect(gate, isA<VarGate>());
    });
  });

  group('MaxRelationshipGate', () {
    test('satisfied when the relationship is at or below the ceiling', () {
      const gate = MaxRelationshipGate('abril', 1);
      expect(gate.isSatisfiedBy(_character(relationships: {'abril': 1})), isTrue);
      expect(gate.isSatisfiedBy(_character(relationships: {'abril': 2})), isFalse);
    });

    test('Gate.fromJson picks MaxRelationshipGate when the JSON declares "max"', () {
      final gate = Gate.fromJson({'type': 'relationship', 'key': 'abril', 'max': 1});
      expect(gate, isA<MaxRelationshipGate>());
    });
  });

  group('ListContainsGate', () {
    test('satisfied when the named list contains the value', () {
      const gate = ListContainsGate('inventory', 'fusible_industrial');
      final character = Character(
        name: 'x',
        level: 1,
        exp: 0,
        attributes: const {},
        resources: const {},
        lists: const {'inventory': ['fusible_industrial']},
      );
      expect(gate.isSatisfiedBy(character), isTrue);
      expect(gate.isSatisfiedBy(_character()), isFalse);
    });

    test('expected: false requires the value to be absent', () {
      const gate = ListContainsGate('inventory', 'fusible_industrial', false);
      expect(gate.isSatisfiedBy(_character()), isTrue);
    });

    test('Gate.fromJson parses the list shape', () {
      final gate = Gate.fromJson({'type': 'list', 'key': 'inventory', 'value': 'x'});
      expect(gate, isA<ListContainsGate>());
    });
  });

  group('MinRelationshipGate', () {
    test('checks the named NPC relationship', () {
      const gate = MinRelationshipGate('lian_suyin', 3);
      expect(
        gate.isSatisfiedBy(_character(relationships: {'lian_suyin': 2})),
        isFalse,
      );
      expect(
        gate.isSatisfiedBy(_character(relationships: {'lian_suyin': 3})),
        isTrue,
      );
    });
  });

  group('AllOfGate / AnyOfGate', () {
    test('AllOfGate requires every sub-gate', () {
      const gate = AllOfGate([MinLevelGate(2), FlagGate('tiene_llave')]);
      expect(gate.isSatisfiedBy(_character(level: 2, flags: {'tiene_llave': true})), isTrue);
      expect(gate.isSatisfiedBy(_character(level: 2)), isFalse);
      expect(gate.isSatisfiedBy(_character(level: 1, flags: {'tiene_llave': true})), isFalse);
    });

    test('AnyOfGate requires at least one sub-gate', () {
      const gate = AnyOfGate([MinLevelGate(5), FlagGate('tiene_llave')]);
      expect(gate.isSatisfiedBy(_character(level: 5)), isTrue);
      expect(gate.isSatisfiedBy(_character(flags: {'tiene_llave': true})), isTrue);
      expect(gate.isSatisfiedBy(_character(level: 1)), isFalse);
    });
  });

  group('Gate.fromJson', () {
    test('parses each gate type from its JSON shape', () {
      expect(
        Gate.fromJson({'type': 'flag', 'key': 'x', 'equals': false}),
        isA<FlagGate>(),
      );
      expect(Gate.fromJson({'type': 'level', 'min': 3}), isA<MinLevelGate>());
      expect(
        Gate.fromJson({'type': 'attribute', 'key': 'espiritu', 'min': 2}),
        isA<MinAttributeGate>(),
      );
      expect(
        Gate.fromJson({'type': 'resource', 'key': 'qi', 'min': 2}),
        isA<MinResourceGate>(),
      );
      expect(
        Gate.fromJson({'type': 'meter', 'key': 'evidence_count', 'min': 2}),
        isA<MinMeterGate>(),
      );
      expect(
        Gate.fromJson({'type': 'relationship', 'key': 'lian_suyin', 'min': 3}),
        isA<MinRelationshipGate>(),
      );
    });

    test('parses nested all/any composites', () {
      final gate = Gate.fromJson({
        'type': 'all',
        'gates': [
          {'type': 'level', 'min': 2},
          {
            'type': 'any',
            'gates': [
              {'type': 'flag', 'key': 'a'},
              {'type': 'flag', 'key': 'b'},
            ],
          },
        ],
      });
      expect(gate, isA<AllOfGate>());
      expect(
        gate.isSatisfiedBy(_character(level: 2, flags: {'b': true})),
        isTrue,
      );
      expect(gate.isSatisfiedBy(_character(level: 2)), isFalse);
    });

    test('throws on an unknown gate type', () {
      expect(
        () => Gate.fromJson({'type': 'unknown'}),
        throwsArgumentError,
      );
    });
  });
}
