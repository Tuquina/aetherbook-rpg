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

  group('assembleEpilogueBeats', () {
    const beats = [
      EpilogueBeat(movement: 'damian', text: 'ep_damian_dead', gate: FlagGate('damian_dead')),
      EpilogueBeat(movement: 'damian', text: 'ep_damian_operator', gate: FlagGate('confessed_to_abril')),
      EpilogueBeat(movement: 'damian', text: 'ep_damian_civil'),
      EpilogueBeat(movement: 'abril', text: 'ep_abril_forgives', gate: FlagGate('abril_forgave')),
      EpilogueBeat(movement: 'abril', text: 'ep_abril_no_forgives'),
    ];

    test('picks the first satisfied beat per movement, preserving movement order', () {
      final result = assembleEpilogueBeats(beats, _character);
      expect(result, ['ep_damian_civil', 'ep_abril_no_forgives']);
    });

    test('an earlier-declared beat wins over a later one when both are satisfied', () {
      final character = _character.copyWith(
        flags: {'confessed_to_abril': true, 'abril_forgave': true},
      );
      final result = assembleEpilogueBeats(beats, character);
      expect(result, ['ep_damian_operator', 'ep_abril_forgives']);
    });

    test('a movement with zero satisfied beats contributes nothing', () {
      const noCatchAll = [
        EpilogueBeat(movement: 'yago', text: 'ep_yago_alive', gate: FlagGate('yago_alive')),
      ];
      expect(assembleEpilogueBeats(noCatchAll, _character), isEmpty);
    });

    test('an empty beat list assembles to nothing', () {
      expect(assembleEpilogueBeats(const [], _character), isEmpty);
    });
  });
}
