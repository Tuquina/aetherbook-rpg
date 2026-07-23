/// The player character — authoritative game state and the source of truth for
/// stats, resources and flags (CLAUDE.md §2.1). Immutable: the engine produces
/// new instances via [copyWith]. Nothing here ever comes from AI prose.
class Character {
  const Character({
    required this.name,
    required this.level,
    required this.exp,
    required this.attributes,
    required this.resources,
    this.flags = const {},
  });

  final String name;
  final int level;
  final int exp;

  /// e.g. `{'cuerpo': 3, 'mente': 4, 'espiritu': 2}`.
  final Map<String, int> attributes;

  /// e.g. `{'qi': 10, 'salud': 20}`.
  final Map<String, int> resources;

  /// Story flags set over the course of play.
  final Map<String, bool> flags;

  int attribute(String key) => attributes[key] ?? 0;
  int resource(String key) => resources[key] ?? 0;
  bool flag(String key) => flags[key] ?? false;

  Character copyWith({
    String? name,
    int? level,
    int? exp,
    Map<String, int>? attributes,
    Map<String, int>? resources,
    Map<String, bool>? flags,
  }) {
    return Character(
      name: name ?? this.name,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      attributes: attributes ?? this.attributes,
      resources: resources ?? this.resources,
      flags: flags ?? this.flags,
    );
  }

  @override
  String toString() =>
      'Character($name, lvl $level, exp $exp, attrs $attributes, '
      'res $resources)';
}
