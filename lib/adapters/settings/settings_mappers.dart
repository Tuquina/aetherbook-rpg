// Pure mapping between UserSettings and the `user_settings.settings` jsonb
// blob (GDD §8 style) — kept free of any Supabase import, same convention as
// `persistence/game_state_mappers.dart`.

import '../../core/settings/user_settings.dart';

Map<String, Object?> userSettingsToJson(UserSettings settings) {
  return {
    'textScale': settings.textScale,
    'typewriterEffect': settings.typewriterEffect,
    'illustrateScenes': settings.illustrateScenes,
    'worldHarshness': settings.worldHarshness.name,
    'suggestActions': settings.suggestActions,
    'showTheRoll': settings.showTheRoll,
    'avoidedThemes': settings.avoidedThemes,
    'reminderFrequency': settings.reminderFrequency,
    'hasSeenOnboarding': settings.hasSeenOnboarding,
  };
}

UserSettings userSettingsFromJson(Map<String, dynamic>? json) {
  if (json == null) return const UserSettings();
  return UserSettings(
    textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
    typewriterEffect: json['typewriterEffect'] as bool? ?? true,
    illustrateScenes: json['illustrateScenes'] as bool? ?? true,
    worldHarshness: WorldHarshness.fromWire(json['worldHarshness'] as String?),
    suggestActions: json['suggestActions'] as bool? ?? true,
    showTheRoll: json['showTheRoll'] as bool? ?? true,
    avoidedThemes: (json['avoidedThemes'] as List?)?.whereType<String>().toList() ?? const [],
    reminderFrequency: json['reminderFrequency'] as String? ?? 'weekly',
    hasSeenOnboarding: json['hasSeenOnboarding'] as bool? ?? false,
  );
}
