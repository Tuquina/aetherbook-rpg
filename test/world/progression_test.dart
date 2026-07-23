import 'package:aetherbook/core/world/progression.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Progression.fromJson', () {
    test('defaults to enabled "nivel" progression when null', () {
      const p = Progression();
      expect(p.enabled, isTrue);
      expect(p.unitLabel, 'nivel');
      expect(p.baseExpPerLevel, 300);
      expect(Progression.fromJson(null).unitLabel, 'nivel');
    });

    test('parses a custom progression', () {
      final p = Progression.fromJson({
        'enabled': true,
        'unit_label': 'reino',
        'base_exp_per_level': 500,
      });
      expect(p.unitLabel, 'reino');
      expect(p.baseExpPerLevel, 500);
      expect(p.unitLabelCapitalized, 'Reino');
    });

    test('supports a world with no progression at all', () {
      final p = Progression.fromJson({'enabled': false});
      expect(p.enabled, isFalse);
    });
  });

  group('World.fromJson progression', () {
    Map<String, dynamic> baseWorld() => {
          'slug': 'x',
          'name': 'X',
          'starting_character': {
            'name': 'P',
            'level': 1,
            'exp': 0,
            'attributes': {'a': 1},
            'resources': {'q': 1},
          },
        };

    test('defaults to enabled progression when the key is absent', () {
      final w = World.fromJson(baseWorld());
      expect(w.progression.enabled, isTrue);
    });

    test('reads the world\'s progression block', () {
      final json = baseWorld()
        ..['progression'] = {
          'enabled': true,
          'unit_label': 'reino',
          'base_exp_per_level': 300,
        };
      final w = World.fromJson(json);
      expect(w.progression.unitLabel, 'reino');
      expect(w.progression.baseExpPerLevel, 300);
    });

    test('a world can declare it has no progression', () {
      final json = baseWorld()..['progression'] = {'enabled': false};
      final w = World.fromJson(json);
      expect(w.progression.enabled, isFalse);
    });
  });
}
