import 'package:aetherbook/adapters/settings/settings_mappers.dart';
import 'package:aetherbook/core/settings/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userSettingsToJson / userSettingsFromJson', () {
    test('round-trips a fully customized settings value', () {
      const settings = UserSettings(
        textScale: 1.2,
        typewriterEffect: false,
        illustrateScenes: false,
        worldHarshness: WorldHarshness.cruel,
        suggestActions: false,
        showTheRoll: true,
        avoidedThemes: ['contenido_sexual', 'crueldad_animal'],
        reminderFrequency: 'never',
        hasSeenOnboarding: true,
      );

      final restored = userSettingsFromJson(userSettingsToJson(settings));

      expect(restored.textScale, settings.textScale);
      expect(restored.typewriterEffect, settings.typewriterEffect);
      expect(restored.illustrateScenes, settings.illustrateScenes);
      expect(restored.worldHarshness, settings.worldHarshness);
      expect(restored.suggestActions, settings.suggestActions);
      expect(restored.showTheRoll, settings.showTheRoll);
      expect(restored.avoidedThemes, settings.avoidedThemes);
      expect(restored.reminderFrequency, settings.reminderFrequency);
      expect(restored.hasSeenOnboarding, settings.hasSeenOnboarding);
    });

    test('a null blob (never saved) defaults to UserSettings()', () {
      final restored = userSettingsFromJson(null);
      expect(restored.textScale, 1.0);
      expect(restored.worldHarshness, WorldHarshness.justo);
      expect(restored.hasSeenOnboarding, isFalse);
    });

    test('an unrecognized worldHarshness string falls back to justo', () {
      final restored = userSettingsFromJson({'worldHarshness': 'nonsense'});
      expect(restored.worldHarshness, WorldHarshness.justo);
    });
  });

  group('WorldHarshness.difficultyOffset', () {
    test('indulgente is easier, cruel is harder, justo is neutral', () {
      expect(WorldHarshness.indulgente.difficultyOffset, -2);
      expect(WorldHarshness.justo.difficultyOffset, 0);
      expect(WorldHarshness.cruel.difficultyOffset, 2);
    });
  });
}
