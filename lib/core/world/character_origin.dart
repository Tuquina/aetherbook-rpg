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

  factory CharacterOrigin.fromJson(Map<String, dynamic> json) {
    return CharacterOrigin(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      baseAttributes: _intMap(json['base_attributes']),
      tagId: json['tag_id'] as String,
      narrativeConnection: json['narrative_connection'] as String? ?? '',
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
}
