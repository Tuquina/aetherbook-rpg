import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

Character _character({
  int level = 1,
  Map<String, int> attributes = const {},
  Map<String, int> resources = const {},
  Map<String, bool> flags = const {},
}) {
  return Character(
    name: 'Discípulo',
    level: level,
    exp: 0,
    attributes: attributes,
    resources: resources,
    flags: flags,
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
