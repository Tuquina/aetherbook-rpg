/// A chargen origin (GDD-adjacent, campaign-bible §5.3): sets a character's
/// base attributes and grants a single "etiqueta" (tag) that later checks may
/// recognize for a conditional bonus (see `core/engine/tag_bonus.dart`).
/// Declarative and per-world/campaign — never hardcoded in the engine.
class CharacterOrigin {
  const CharacterOrigin({
    required this.id,
    required this.displayName,
    required this.baseAttributes,
    required this.tagId,
    this.narrativeConnection = '',
    this.seedNarration,
    this.seedChoices = const [],
  });

  final String id;
  final String displayName;

  /// Attribute key -> starting value for this origin, e.g.
  /// `{'cuerpo': 3, 'espiritu': 2}`. Attributes not listed here still start
  /// at 1 (campaign-bible rule: "todos los atributos comienzan en 1").
  final Map<String, int> baseAttributes;

  /// The tag this origin grants (e.g. `'disciplina_de_secta'`). A character
  /// carries exactly one tag; it never stacks with another.
  final String tagId;

  /// Flavor text describing how this origin connects to the story.
  final String narrativeConnection;

  /// This origin's own opening scene for a freeform world (CLAUDE.md Fase 2):
  /// the seed narration must actually reflect *how* the character arrived
  /// (e.g. isekai's "transportado en combate" opens mid-fight, not on a
  /// generic empty room), so it can't be one shared string per world. `null`
  /// falls back to `World.seedNarration` — a world with no per-origin seed
  /// authored yet (or a curated world's origins, which never render this at
  /// all) keeps working exactly as before.
  final String? seedNarration;

  /// This origin's own starter choices, shown alongside [seedNarration].
  /// Empty falls back to `World.seedChoices`.
  final List<String> seedChoices;

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        if (baseAttributes.isNotEmpty) 'base_attributes': baseAttributes,
        'tag_id': tagId,
        if (narrativeConnection.isNotEmpty) 'narrative_connection': narrativeConnection,
        if (seedNarration != null) 'seed_narration': seedNarration,
        if (seedChoices.isNotEmpty) 'seed_choices': seedChoices,
      };

  factory CharacterOrigin.fromJson(Map<String, dynamic> json) {
    return CharacterOrigin(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      baseAttributes: _intMap(json['base_attributes']),
      tagId: json['tag_id'] as String,
      narrativeConnection: json['narrative_connection'] as String? ?? '',
      seedNarration: json['seed_narration'] as String?,
      seedChoices: _stringList(json['seed_choices']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is Map) {
      return value.map(
        (key, v) => MapEntry(key as String, (v as num).toInt()),
      );
    }
    return const {};
  }
}
