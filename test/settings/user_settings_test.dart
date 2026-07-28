import 'package:aetherbook/core/settings/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserSettings.avoidedThemeLabels', () {
    test('resolves ids to labels, in catalog order', () {
      const settings = UserSettings(
        avoidedThemes: ['crueldad_animal', 'violencia_grafica'],
      );
      expect(settings.avoidedThemeLabels, [
        'Violencia gráfica explícita',
        'Crueldad animal',
      ]);
    });

    test('is empty when no theme is marked', () {
      const settings = UserSettings();
      expect(settings.avoidedThemeLabels, isEmpty);
    });

    test('ignores an unrecognized id instead of throwing', () {
      const settings = UserSettings(avoidedThemes: ['algo_inventado']);
      expect(settings.avoidedThemeLabels, isEmpty);
    });
  });

  group('UserSettings.copyWith', () {
    test('overrides only the given fields, keeps the rest', () {
      const settings = UserSettings(textScale: 1.2, hasSeenOnboarding: true);
      final updated = settings.copyWith(worldHarshness: WorldHarshness.cruel);
      expect(updated.textScale, 1.2);
      expect(updated.hasSeenOnboarding, isTrue);
      expect(updated.worldHarshness, WorldHarshness.cruel);
    });
  });
}
