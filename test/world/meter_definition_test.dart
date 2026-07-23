import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/meter_definition.dart';
import 'package:flutter_test/flutter_test.dart';

Character _character({
  Map<String, int> meters = const {},
  Map<String, bool> flags = const {},
}) {
  return Character(
    name: 'Protagonista',
    level: 1,
    exp: 0,
    attributes: const {},
    resources: const {},
    flags: flags,
    meters: meters,
  );
}

void main() {
  group('MeterDefinition.clamp', () {
    test('clamps to a lower bound (e.g. karma -3)', () {
      const def = MeterDefinition(min: -3, max: 3);
      expect(def.clamp(-5), -3);
    });

    test('clamps to an upper bound', () {
      const def = MeterDefinition(min: -3, max: 3);
      expect(def.clamp(10), 3);
    });

    test('an unbounded-above meter (e.g. ledger_debt) never clamps upward', () {
      const def = MeterDefinition(min: 0);
      expect(def.clamp(999), 999);
      expect(def.clamp(-5), 0);
    });

    test('a fully unbounded meter passes values through', () {
      const def = MeterDefinition();
      expect(def.clamp(-100), -100);
      expect(def.clamp(100), 100);
    });
  });

  group('MeterDefinition.resolve', () {
    test('a stored meter resolves to its clamped character value', () {
      const def = MeterDefinition(min: 0, max: 6);
      final character = _character(meters: {'celestial_pressure': 9});
      expect(def.resolve(character, 'celestial_pressure'), 6);
    });

    test('a derived meter counts true flags, ignoring any stored value', () {
      const def = MeterDefinition(
        derivedFromFlags: [
          'evidence_forged_seal',
          'evidence_donors_alive',
          'evidence_storm_is_memory',
          'evidence_original_covenant',
        ],
      );
      final character = _character(
        meters: {'evidence_count': 999}, // must be ignored
        flags: {
          'evidence_forged_seal': true,
          'evidence_donors_alive': true,
          'evidence_storm_is_memory': false,
        },
      );
      expect(def.resolve(character, 'evidence_count'), 2);
      expect(def.isDerived, isTrue);
    });
  });

  group('MeterDefinition.fromJson', () {
    test('parses bounds and initial value', () {
      final def = MeterDefinition.fromJson({'min': -3, 'max': 3, 'initial': 0});
      expect(def.min, -3);
      expect(def.max, 3);
      expect(def.initial, 0);
      expect(def.isDerived, isFalse);
    });

    test('parses a derived meter', () {
      final def = MeterDefinition.fromJson({
        'derived_from_flags': ['a', 'b'],
      });
      expect(def.isDerived, isTrue);
      expect(def.derivedFromFlags, ['a', 'b']);
    });
  });
}
