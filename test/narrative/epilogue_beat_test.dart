import 'package:aetherbook/core/narrative/epilogue_beat.dart';
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
  group('EpilogueBeat', () {
    test('isSatisfiedBy defaults to AlwaysGate', () {
      const beat = EpilogueBeat(movement: 'la_tablilla', text: 'x');
      expect(beat.isSatisfiedBy(_character), isTrue);
    });

    test('isSatisfiedBy respects a declared gate', () {
      const beat = EpilogueBeat(
        movement: 'una_persona_afectada',
        text: 'Suyin se presenta de nuevo a Tao.',
        gate: FlagGate('tao_stabilized'),
      );
      expect(beat.isSatisfiedBy(_character), isFalse);
      expect(
        beat.isSatisfiedBy(_character.copyWith(flags: {'tao_stabilized': true})),
        isTrue,
      );
    });

    test('fromJson parses movement, text and gate', () {
      final beat = EpilogueBeat.fromJson({
        'movement': 'la_nueva_regla',
        'text': 'La Bóveda se administra en una plaza.',
        'gate': {'type': 'flag', 'key': 'ending_nuevo_pacto'},
      });
      expect(beat.movement, 'la_nueva_regla');
      expect(beat.text, 'La Bóveda se administra en una plaza.');
      expect(beat.isSatisfiedBy(_character), isFalse);
    });
  });
}
