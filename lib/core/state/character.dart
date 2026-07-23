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
    this.relationships = const {},
    this.lists = const {},
    this.vars = const {},
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

  /// Per-NPC relationship scores (campaign-bible §8.2), range `[-2, 3]` by
  /// default (a curated world may widen this — see `World.relationshipMin`/
  /// `relationshipMax`). Changed only through `ApplyStateDeltas`, never set
  /// directly.
  final Map<String, int> relationships;

  /// Named string lists a curated campaign declares — e.g.
  /// `lists['inventory']` (item ids) or `lists['selected_passengers']` (NPC
  /// ids). One generic mechanism instead of a bespoke list per concept
  /// (campaign-bible §8.3/§8.5: "no persistir nombres, usar IDs").
  final Map<String, List<String>> lists;

  /// Named free-form id/enum-like state a curated campaign declares — e.g.
  /// `vars['passenger_policy']`, `vars['selected_profile_id']`. For state
  /// that isn't boolean, numeric or a per-NPC score.
  final Map<String, String> vars;

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
  int relationship(String key) => relationships[key] ?? 0;
  List<String> list(String key) => lists[key] ?? const [];
  String? varValue(String key) => vars[key];

  Character copyWith({
    String? name,
    int? level,
    int? exp,
    Map<String, int>? attributes,
    Map<String, int>? resources,
    Map<String, bool>? flags,
    Map<String, int>? meters,
    Map<String, int>? relationships,
    Map<String, List<String>>? lists,
    Map<String, String>? vars,
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
      relationships: relationships ?? this.relationships,
      lists: lists ?? this.lists,
      vars: vars ?? this.vars,
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
