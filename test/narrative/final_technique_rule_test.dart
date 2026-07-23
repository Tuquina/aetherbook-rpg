import 'package:aetherbook/core/narrative/final_technique_rule.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {},
  resources: {},
);

void main() {
  group('FinalTechniqueRule', () {
    test('isSatisfiedBy respects the declared gate', () {
      const rule = FinalTechniqueRule(
        gate: MinMeterGate('ledger_debt', 3),
        techniqueId: 'nombre_que_devora_nombres',
      );
      expect(rule.isSatisfiedBy(_character), isFalse);
      expect(
        rule.isSatisfiedBy(_character.copyWith(meters: {'ledger_debt': 3})),
        isTrue,
      );
    });

    test('a catch-all rule uses AlwaysGate', () {
      const rule = FinalTechniqueRule(
        gate: AlwaysGate(),
        techniqueId: 'yo_me_nombro',
      );
      expect(rule.isSatisfiedBy(_character), isTrue);
    });

    test('fromJson parses gate and technique_id', () {
      final rule = FinalTechniqueRule.fromJson({
        'gate': {'type': 'meter', 'key': 'ledger_debt', 'min': 3},
        'technique_id': 'nombre_que_devora_nombres',
      });
      expect(rule.techniqueId, 'nombre_que_devora_nombres');
      expect(rule.isSatisfiedBy(_character), isFalse);
    });
  });
}
