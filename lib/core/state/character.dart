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
    this.meters = const {},
    this.originId,
    this.originTagId,
    this.vowId,
    this.personalItem,
  });

  final String name;
  final int level;
  final int exp;

  /// e.g. `{'cuerpo': 3, 'mente': 4, 'espiritu': 2}`.
  final Map<String, int> attributes;

  /// Spendable pools with a world-declared maximum, e.g. `{'qi': 10}`.
  final Map<String, int> resources;

  /// Story flags set over the course of play.
  final Map<String, bool> flags;

  /// Named narrative-economy counters a world/campaign declares beyond
  /// attributes and resources — e.g. `karma`, `celestial_pressure`,
  /// `ledger_debt`, `public_trust` in a campaign bible. Unlike resources,
  /// these aren't spent on techniques; they gate content and endings. See
  /// `core/world/meter_definition.dart` for bounds and derived meters.
  final Map<String, int> meters;

  /// The chargen origin chosen at creation (campaign-bible §5.3), or `null`
  /// for worlds that don't use structured character creation.
  final String? originId;

  /// Denormalized from the origin at creation time: the single tag it
  /// grants, used by `core/engine/tag_bonus.dart` for a conditional +2.
  final String? originTagId;

  /// The vow/juramento chosen at creation (campaign-bible §5.4), or `null`.
  final String? vowId;

  /// Free-text description of the personal object the character carries
  /// (campaign-bible §5.1). Confers no automatic bonus.
  final String? personalItem;

  int attribute(String key) => attributes[key] ?? 0;
  int resource(String key) => resources[key] ?? 0;
  bool flag(String key) => flags[key] ?? false;
  int meter(String key) => meters[key] ?? 0;

  Character copyWith({
    String? name,
    int? level,
    int? exp,
    Map<String, int>? attributes,
    Map<String, int>? resources,
    Map<String, bool>? flags,
    Map<String, int>? meters,
    String? originId,
    String? originTagId,
    String? vowId,
    String? personalItem,
  }) {
    return Character(
      name: name ?? this.name,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      attributes: attributes ?? this.attributes,
      resources: resources ?? this.resources,
      flags: flags ?? this.flags,
      meters: meters ?? this.meters,
      originId: originId ?? this.originId,
      originTagId: originTagId ?? this.originTagId,
      vowId: vowId ?? this.vowId,
      personalItem: personalItem ?? this.personalItem,
    );
  }

  @override
  String toString() =>
      'Character($name, lvl $level, exp $exp, attrs $attributes, '
      'res $resources)';
}
