import 'package:aetherbook/core/engine/tag_bonus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tagBonus = TagBonus();

  group('TagBonus', () {
    test('grants +2 when the character\'s tag matches the check\'s tag', () {
      expect(
        tagBonus.evaluate(
          characterTagId: 'disciplina_de_secta',
          checkTagId: 'disciplina_de_secta',
        ),
        2,
      );
    });

    test('grants 0 when the tags differ', () {
      expect(
        tagBonus.evaluate(
          characterTagId: 'disciplina_de_secta',
          checkTagId: 'medicina_y_meridianos',
        ),
        0,
      );
    });

    test('grants 0 when the character has no tag', () {
      expect(
        tagBonus.evaluate(characterTagId: null, checkTagId: 'medicina'),
        0,
      );
    });

    test('grants 0 when the check declares no relevant tag', () {
      expect(
        tagBonus.evaluate(characterTagId: 'disciplina_de_secta', checkTagId: null),
        0,
      );
    });

    test('the bonus amount is configurable but defaults to 2', () {
      const custom = TagBonus(bonus: 5);
      expect(
        custom.evaluate(characterTagId: 'a', checkTagId: 'a'),
        5,
      );
    });
  });
}
