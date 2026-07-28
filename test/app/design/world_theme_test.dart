import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/app/design/world_theme.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

World _worldWith({
  String? accent,
  String? base,
  String? secondary,
  String? titleFont,
  int? titleWeight,
  double? titleTracking,
  bool titleUppercase = false,
  String? titleColor,
  String? texture,
}) =>
    World(
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
      themeTitleFontFamily: titleFont,
      themeTitleFontWeight: titleWeight,
      themeTitleLetterSpacing: titleTracking,
      themeTitleUppercase: titleUppercase,
      themeTitleColorHex: titleColor,
      themeTexture: texture,
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

  group('WorldTheme.titleStyle', () {
    const fallback = TextStyle(fontFamily: 'Marcellus', fontWeight: FontWeight.w600);

    test('a themeless world renders the base style unchanged', () {
      final theme = WorldTheme.forWorld(_worldWith());
      final style = theme.titleStyle(fallback);
      expect(style.fontFamily, fallback.fontFamily);
      expect(style.fontWeight, fallback.fontWeight);
      expect(style.letterSpacing, isNull);
      expect(style.color, isNull);
      expect(theme.titleUppercase, isFalse);
      expect(theme.texture, isNull);
    });

    test('applies a declared title treatment over the base style', () {
      final theme = WorldTheme.forWorld(_worldWith(
        titleFont: 'Archivo',
        titleWeight: 800,
        titleTracking: -0.4,
        titleUppercase: true,
        texture: 'hard_diagonal',
      ));
      final style = theme.titleStyle(fallback);
      expect(style.fontFamily, 'Archivo');
      expect(style.fontWeight, FontWeight.w800);
      expect(style.letterSpacing, -0.4);
      expect(style.color, isNull); // no title_color declared -> keeps base's
      expect(theme.titleUppercase, isTrue);
      expect(theme.texture, WorldTextureKind.hardDiagonal);
    });

    test('a declared title color overrides the base style\'s color', () {
      final theme = WorldTheme.forWorld(_worldWith(titleColor: '#D6D2AC'));
      final style = theme.titleStyle(fallback.copyWith(color: AetherColors.parchment));
      expect(style.color, const Color(0xFFD6D2AC));
    });

    test('an unrecognized texture string falls back to null (default)', () {
      final theme = WorldTheme.forWorld(_worldWith(texture: 'not-a-texture'));
      expect(theme.texture, isNull);
    });
  });
}
