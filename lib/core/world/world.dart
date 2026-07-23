import '../state/character.dart';

/// A declarative world package (CLAUDE.md §8, GDD §4.6). Everything that gives
/// a world its identity — rules, tone, the narrator's system prompt, starting
/// character and opening seed — lives in data, not in engine code. Adding a
/// world means adding a data file, never touching the engine.
class World {
  const World({
    required this.slug,
    required this.name,
    required this.theme,
    required this.tone,
    required this.systemPrompt,
    required this.imageStyleSuffix,
    required this.defaultDifficulty,
    required this.criticalMargin,
    required this.primaryAttribute,
    this.attributeKeywords = const {},
    required this.startingCharacter,
    required this.seedNarration,
    required this.seedChoices,
  });

  final String slug;
  final String name;
  final String theme;
  final String tone;

  /// System prompt for the narrator (used by the real AI adapter later).
  final String systemPrompt;

  /// Fixed suffix appended to every image prompt for visual consistency.
  final String imageStyleSuffix;

  /// Default difficulty for freeform checks in this world.
  final int defaultDifficulty;

  /// Margin above the difficulty that turns a success into a critical.
  final int criticalMargin;

  /// Fallback attribute when no keyword in [attributeKeywords] matches the
  /// action text (CLAUDE.md §2.2, GDD §4.1).
  final String primaryAttribute;

  /// Keywords that map an action's text to an attribute (e.g. `'cuerpo':
  /// ['forzar', 'pelear']`), used by `InferActionAttribute`. Declarative and
  /// per-world (CLAUDE.md §8) — the engine never hardcodes what "forzar"
  /// means for a given world.
  final Map<String, List<String>> attributeKeywords;

  final Character startingCharacter;

  /// Opening narration and choices shown before the first action.
  final String seedNarration;
  final List<String> seedChoices;

  factory World.fromJson(Map<String, dynamic> json) {
    final resolution =
        (json['resolution'] as Map?)?.cast<String, dynamic>() ?? const {};
    final seed = (json['seed'] as Map?)?.cast<String, dynamic>() ?? const {};

    return World(
      slug: json['slug'] as String,
      name: json['name'] as String,
      theme: json['theme'] as String? ?? '',
      tone: json['tone'] as String? ?? '',
      systemPrompt: json['system_prompt'] as String? ?? '',
      imageStyleSuffix: json['image_style_suffix'] as String? ?? '',
      defaultDifficulty: (resolution['default_difficulty'] as num?)?.toInt() ??
          12,
      criticalMargin: (resolution['critical_margin'] as num?)?.toInt() ?? 5,
      primaryAttribute: resolution['primary_attribute'] as String? ?? 'cuerpo',
      attributeKeywords: _keywordsFromJson(resolution['attribute_keywords']),
      startingCharacter: _characterFromJson(
        (json['starting_character'] as Map).cast<String, dynamic>(),
      ),
      seedNarration: seed['narration'] as String? ?? '',
      seedChoices: _stringList(seed['choices']),
    );
  }

  static Character _characterFromJson(Map<String, dynamic> json) {
    return Character(
      name: json['name'] as String? ?? 'Protagonista',
      level: (json['level'] as num?)?.toInt() ?? 1,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      attributes: _intMap(json['attributes']),
      resources: _intMap(json['resources']),
    );
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(key as String, (v as num).toInt()),
      );
    }
    return const {};
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static Map<String, List<String>> _keywordsFromJson(Object? value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(key as String, _stringList(v)),
      );
    }
    return const {};
  }
}
