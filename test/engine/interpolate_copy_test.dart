import 'package:aetherbook/core/engine/interpolate_copy.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Damián',
  level: 1,
  exp: 0,
  attributes: {},
  resources: {'ammo': 3},
  meters: {'winter_survivors': 41},
  vars: {'passenger_policy': 'vulnerables_primero'},
);

void main() {
  const interpolate = InterpolateCopy();

  test('returns the text unchanged when there are no tokens', () {
    expect(
      interpolate('Damián sube.', character: _character),
      'Damián sube.',
    );
  });

  test('substitutes a resource token', () {
    expect(
      interpolate('Quedan {{ammo}} balas.', character: _character),
      'Quedan 3 balas.',
    );
  });

  test('substitutes a meter token', () {
    expect(
      interpolate(
        'Sobreviven {{winter_survivors}} de acuerdo con el estado.',
        character: _character,
      ),
      'Sobreviven 41 de acuerdo con el estado.',
    );
  });

  test('substitutes a var token', () {
    expect(
      interpolate('La política elegida fue {{passenger_policy}}.', character: _character),
      'La política elegida fue vulnerables_primero.',
    );
  });

  test('substitutes {{name}} with protagonistName when provided', () {
    expect(
      interpolate('{{name}} mira la vía.', character: _character, protagonistName: 'Damián'),
      'Damián mira la vía.',
    );
  });

  test('leaves an unknown token untouched rather than throwing', () {
    expect(
      interpolate('{{no_existe}}', character: _character),
      '{{no_existe}}',
    );
  });

  test('substitutes multiple tokens in the same string', () {
    expect(
      interpolate(
        '{{name}} cuenta {{ammo}} balas y {{winter_survivors}} sobrevivientes.',
        character: _character,
        protagonistName: 'Damián',
      ),
      'Damián cuenta 3 balas y 41 sobrevivientes.',
    );
  });
}
