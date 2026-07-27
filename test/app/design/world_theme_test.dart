import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/app/design/world_theme.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

World _worldWith({String? accent, String? base, String? secondary}) => World(
      slug: 'test',
      name: 'Mundo de prueba',
      theme: 'test',
      tone: 'neutro',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: 'cuerpo',
      startingCharacter: const Character(
          name: 'Protagonista', level: 1, exp: 0, attributes: {}, resources: {}),
      seedNarration: '',
      seedChoices: const [],
      themeAccentHex: accent,
      themeBaseHex: base,
      themeSecondaryHex: secondary,
    );

void main() {
  group('WorldTheme.parseHexColor', () {
    test('parses a "#RRGGBB" string', () {
      expect(WorldTheme.parseHexColor('#7FD4C1'), const Color(0xFF7FD4C1));
    });

    test('parses a bare "RRGGBB" string, no leading #', () {
      expect(WorldTheme.parseHexColor('7FD4C1'), const Color(0xFF7FD4C1));
    });

    test('returns null for null, malformed, or wrong-length input', () {
      expect(WorldTheme.parseHexColor(null), isNull);
      expect(WorldTheme.parseHexColor('not-a-color'), isNull);
      expect(WorldTheme.parseHexColor('#FFF'), isNull);
      expect(WorldTheme.parseHexColor(''), isNull);
    });
  });

  group('WorldTheme.forWorld', () {
    test('falls back to the global palette when a world declares no theme', () {
      final theme = WorldTheme.forWorld(_worldWith());
      expect(theme.accent, AetherColors.gold);
      expect(theme.base, AetherColors.ink);
      expect(theme.secondary, AetherColors.nova);
    });

    test('resolves a world\'s declared theme colors', () {
      final theme = WorldTheme.forWorld(_worldWith(
        accent: '#7FD4C1',
        base: '#0F1D1A',
        secondary: '#D8B65E',
      ));
      expect(theme.accent, const Color(0xFF7FD4C1));
      expect(theme.base, const Color(0xFF0F1D1A));
      expect(theme.secondary, const Color(0xFFD8B65E));
    });

    test('a malformed hex value falls back individually, not the whole theme', () {
      final theme = WorldTheme.forWorld(_worldWith(accent: 'nope', base: '#0F1D1A'));
      expect(theme.accent, AetherColors.gold); // fell back
      expect(theme.base, const Color(0xFF0F1D1A)); // parsed fine
      expect(theme.secondary, AetherColors.nova); // never declared, fell back
    });
  });
}
