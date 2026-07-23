import '../state/character.dart';
import 'meter_definition.dart';
import 'progression.dart';
import 'resource_formula.dart';

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
    this.progression = const Progression(),
    this.resourceFormulas = const {},
    this.meterDefinitions = const {},
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

  /// How this world models advancement (levels/realms/none). See [Progression].
  final Progression progression;

  /// Resource key -> formula (e.g. `'vitality': 8 + cuerpo*2`), for worlds
  /// whose pools scale with attributes (campaign-bible format) instead of a
  /// flat starting number.
  final Map<String, ResourceFormula> resourceFormulas;

  /// Named narrative-economy counters this world declares (karma, narrative
  /// pressure, debt…), with their bounds and whether they're derived from
  /// flags. See [MeterDefinition].
  final Map<String, MeterDefinition> meterDefinitions;

  final Character startingCharacter;

  /// Opening narration and choices shown before the first action.
  final String seedNarration;
  final List<String> seedChoices;

  /// The declared maximum for [resourceKey] given [character]'s current
  /// attributes, or `null` if this world declares no formula for it (a
  /// simple flat resource with no tracked ceiling).
  int? maxResource(String resourceKey, Character character) =>
      resourceFormulas[resourceKey]?.evaluate(character.attributes);

  /// The effective value of a declared meter for [character] — resolves
  /// derived meters (e.g. `evidence_count`) from flags instead of a stored
  /// value. Falls back to the raw stored meter if this world declares no
  /// definition for [key].
  int meterValue(String key, Character character) {
    final definition = meterDefinitions[key];
    if (definition == null) return character.meter(key);
    return definition.resolve(character, key);
  }

  factory World.fromJson(Map<String, dynamic> json) {
    final resolution =
        (json['resolution'] as Map?)?.cast<String, dynamic>() ?? const {};
    final seed = (json['seed'] as Map?)?.cast<String, dynamic>() ?? const {};
    final resourceFormulas = _resourceFormulasFromJson(json['resources']);
    final meterDefinitions = _meterDefinitionsFromJson(json['meters']);

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
      progression: Progression.fromJson(
        (json['progression'] as Map?)?.cast<String, dynamic>(),
      ),
      resourceFormulas: resourceFormulas,
      meterDefinitions: meterDefinitions,
      startingCharacter: _characterFromJson(
        (json['starting_character'] as Map).cast<String, dynamic>(),
        resourceFormulas: resourceFormulas,
        meterDefinitions: meterDefinitions,
      ),
      seedNarration: seed['narration'] as String? ?? '',
      seedChoices: _stringList(seed['choices']),
    );
  }

  static Character _characterFromJson(
    Map<String, dynamic> json, {
    required Map<String, ResourceFormula> resourceFormulas,
    required Map<String, MeterDefinition> meterDefinitions,
  }) {
    final attributes = _intMap(json['attributes']);

    // A world-declared formula overrides a flat starting value for the same
    // key — most worlds need neither and just declare flat resources.
    final resources = {
      ..._intMap(json['resources']),
      for (final entry in resourceFormulas.entries)
        entry.key: entry.value.evaluate(attributes),
    };

    final meters = {
      for (final entry in meterDefinitions.entries)
        if (!entry.value.isDerived) entry.key: entry.value.initial,
    };

    return Character(
      name: json['name'] as String? ?? 'Protagonista',
      level: (json['level'] as num?)?.toInt() ?? 1,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      attributes: attributes,
      resources: resources,
      meters: meters,
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

  static Map<String, ResourceFormula> _resourceFormulasFromJson(Object? value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(key as String, ResourceFormula.fromJson(v)),
      );
    }
    return const {};
  }

  static Map<String, MeterDefinition> _meterDefinitionsFromJson(Object? value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(
          key as String,
          MeterDefinition.fromJson((v as Map).cast<String, dynamic>()),
        ),
      );
    }
    return const {};
  }
}
