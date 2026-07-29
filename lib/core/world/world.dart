import '../narrative/abstract_opponent.dart';
import '../narrative/story_graph.dart';
import '../state/character.dart';
import 'character_origin.dart';
import 'character_tag_rule.dart';
import 'codex_place.dart';
import 'codex_term.dart';
import 'item_definition.dart';
import 'meter_definition.dart';
import 'npc.dart';
import 'progression.dart';
import 'rank_definition.dart';
import 'resource_formula.dart';
import 'technique.dart';
import 'tone_option.dart';
import 'vow.dart';

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
    this.intentKeywords = const {},
    this.riskKeywords = const {},
    this.selfGrantPatterns = const [],
    this.progression = const Progression(),
    this.resourceFormulas = const {},
    this.meterDefinitions = const {},
    this.attributeKeys = const [],
    this.origins = const [],
    this.vows = const [],
    this.tones = const [],
    this.ranks = const [],
    this.opponents = const [],
    this.npcs = const [],
    this.techniques = const [],
    this.items = const [],
    this.places = const [],
    this.terms = const [],
    this.characterTags = const [],
    this.storyGraph,
    required this.startingCharacter,
    required this.seedNarration,
    required this.seedChoices,
    this.personalItemSeedHook,
    this.aiRuntimeRequired = true,
    this.allowFreeText = true,
    this.catalogDescription,
    this.estimatedDurationMinutes,
    this.contentWarning,
    this.relationshipMagnitudeCap = 1,
    this.relationshipMin = -2,
    this.relationshipMax = 3,
    this.hasFreeAttributePoint = true,
    this.chargenVowLabel = 'Juramento',
    this.hasCustomizableName = true,
    this.themeAccentHex,
    this.themeBaseHex,
    this.themeSecondaryHex,
    this.themeTitleFontFamily,
    this.themeTitleFontWeight,
    this.themeTitleLetterSpacing,
    this.themeTitleUppercase = false,
    this.themeTitleColorHex,
    this.themeTexture,
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

  /// Keywords that map a free action's text to a `ClassifyFreeAction` intent
  /// (e.g. `'force': ['forzar', 'romper']`), keyed by the intent's wire name
  /// (campaign-bible §18.7). Empty for worlds that don't classify free
  /// actions beyond their attribute.
  final Map<String, List<String>> intentKeywords;

  /// Keywords that map a free action's text to a `RiskLevel`, keyed by the
  /// risk's name (e.g. `'high': ['sin cobertura', 'a ciegas']`).
  final Map<String, List<String>> riskKeywords;

  /// Substrings that flag a free action as an attempt to self-grant state
  /// the AI isn't allowed to touch (rank, items, kinship — campaign-bible
  /// §18.7's last rule), making it `CanonCompatibility.invalid`.
  final List<String> selfGrantPatterns;

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

  /// Every attribute this world/campaign defines, e.g. `['cuerpo', 'agudeza',
  /// 'espiritu', 'presencia']`. Used by [CreateCharacter] to seed every
  /// attribute at `1` before an origin's overrides apply (campaign-bible
  /// §5.3: "todos los atributos comienzan en 1"). Simple worlds that build
  /// their starting character directly from JSON (Fase 0 style) can leave
  /// this empty.
  final List<String> attributeKeys;

  /// Chargen origins available for structured character creation (§5.3).
  /// Empty for worlds that don't use this chargen flow.
  final List<CharacterOrigin> origins;

  /// Chargen vows available for structured character creation (§5.4).
  final List<Vow> vows;

  /// Narrative tones the player can pick at chargen (V2), each with its own
  /// preview text for this world. Empty for a world that doesn't offer the
  /// tone step at all (every world predating this field, and any curated/
  /// hybrid campaign that intentionally keeps its own fixed authorial tone).
  final List<ToneOption> tones;

  /// Milestone-gated ranks (§7.1). Empty for worlds using the simpler linear
  /// [progression] instead. See `core/engine/rank_progression.dart`.
  final List<RankDefinition> ranks;

  /// Named opponents this campaign declares for abstract combat (§6.13).
  final List<AbstractOpponent> opponents;

  /// Recurring named cast members (§4), for narrator context and free-action
  /// `targetId` resolution. Empty for worlds with no structured cast.
  final List<Npc> npcs;

  /// Declared techniques (§7.3-7.5): initial, forbidden and final. Empty for
  /// worlds that don't use the technique system.
  final List<Technique> techniques;

  /// Descriptions for ids that can end up in `character.lists['inventory']`
  /// (via `list_add`/`list_remove` state deltas). A world doesn't have to
  /// describe every id it ever adds — `findItem` degrades gracefully for one
  /// that isn't here yet.
  final List<ItemDefinition> items;

  /// Places worth remembering in the Códice's per-story glossary (V2 §1a) —
  /// pure lore, revealed via a `StoryNode.codexReveals` entry. Empty for
  /// freeform worlds, which have no node graph to hang a reveal off of.
  final List<CodexPlace> places;

  /// Terms/concepts worth remembering in the Códice's per-story glossary,
  /// same reveal mechanism as [places].
  final List<CodexTerm> terms;

  /// Rules turning one of the character's own boolean flags into a visible
  /// tag on `CharacterSheetSheet` (V2 §4c) — evaluated live against
  /// whichever flags are currently set, not tied to a specific node like
  /// [places]/[terms] are. Empty for a world that declares none.
  final List<CharacterTagRule> characterTags;

  /// The hybrid-campaign node graph (§9), or `null` for freeform worlds with
  /// no curated/hybrid content (Fase 0 style).
  final StoryGraph? storyGraph;

  final Character startingCharacter;

  /// Opening narration and choices shown before the first action — the
  /// fallback used when the player's chosen `CharacterOrigin` declares no
  /// `seedNarration`/`seedChoices` of its own (or for a world/campaign that
  /// never shows this at all, like a graph-driven one).
  final String seedNarration;
  final List<String> seedChoices;

  /// A short closing paragraph appended to the opening scene only when the
  /// player actually filled in a personal item at chargen (CLAUDE.md Fase 2:
  /// asking for one and then never using it makes the field pointless).
  /// Written generically enough ("sigues llevando encima {{personalItem}}")
  /// to read naturally regardless of which origin the character picked, so
  /// one per world is enough — `null`/empty for a world that hasn't
  /// authored one yet.
  final String? personalItemSeedHook;

  /// Whether this world's curated turns need `NarratorPort` at all
  /// (campaign-bible §9.1/§25.10: "ai_runtime_required"). `false` means every
  /// reachable outcome in [storyGraph] carries its own literal
  /// `ChoiceOutcome.resultText`/`EpilogueBeat.text`/`FixedAnchorNode.narration`
  /// — `GameController` never calls the narrator for this world, curated or
  /// not. `true` (default) preserves the original hybrid behavior, where the
  /// AI always dresses the turn.
  final bool aiRuntimeRequired;

  /// Whether the free-text action field is offered at all (campaign-bible
  /// `free_text_actions`). `false` for a fully curated campaign with no
  /// freeform input; `true` (default) preserves existing worlds' behavior.
  final bool allowFreeText;

  /// Optional catalog metadata shown on the world-select card
  /// (`WorldSelectScreen`) when present — none of these are required, and a
  /// world that omits them renders exactly as before.
  final String? catalogDescription;
  final int? estimatedDurationMinutes;
  final String? contentWarning;

  /// Per-world overrides for `ApplyStateDeltas`'s relationship-delta safety
  /// limits (see its doc comments) — default to the original AI-safety
  /// values (`±1`, range `[-2, 3]`). A curated world with pre-vetted,
  /// human-authored effects can widen these.
  final int relationshipMagnitudeCap;
  final int relationshipMin;
  final int relationshipMax;

  /// Whether `ChargenScreen` offers the free `+1` attribute step at all
  /// (default `true`, matching every existing world). `false` for a world
  /// whose origins are already complete, fixed builds with no further
  /// customization (campaign-bible's "perfiles de supervivencia", each
  /// already summing to its full point budget).
  final bool hasFreeAttributePoint;

  /// Display label for the vow-selection step in `ChargenScreen` (default
  /// `'Juramento'`). A curated world can repurpose the `vows` mechanism for
  /// a differently-framed fixed choice (e.g. "Recuerdo conservado") without
  /// the UI showing a mismatched label.
  final String chargenVowLabel;

  /// Whether `ChargenScreen` asks the player to name their character at all
  /// (default `true`, matching every existing world). `false` for a world
  /// whose protagonist is a specific, already-named person the narration
  /// refers to by name throughout (e.g. "Damián Salvatierra") — asking for a
  /// player name there would only produce a UI that shows one name while
  /// every line of prose uses another. `startingCharacter.name` is used as
  /// the fixed name in that case.
  final bool hasCustomizableName;

  /// Per-world visual accent/base/secondary colors, as raw `"#RRGGBB"` hex
  /// strings (V2 design prototype §4a-4d: "un juego de tokens por
  /// ambientación") — `null` for a world that hasn't declared theming yet,
  /// which falls back to the app's single global palette. Hex strings, not
  /// `Color`, because `core/` stays Flutter-free (`core_purity_test.dart`
  /// forbids `dart:ui`/`package:flutter` imports here); parsing them into an
  /// actual `Color` is `lib/app/design/world_theme.dart`'s job.
  final String? themeAccentHex;
  final String? themeBaseHex;
  final String? themeSecondaryHex;

  /// Per-world title-treatment tokens (V2 §4a: "tratamiento de títulos") —
  /// `null`/`false` fields fall back to `AetherType`'s fixed Marcellus/600
  /// styling, same degrade-gracefully pattern as the color tokens above.
  /// Applied only where the mockup itself applies it (the scene and the
  /// character sheet) — `MyStoriesScreen`/`WorldSelectScreen` stay
  /// deliberately neutral (§4d: "biblioteca sin tema propio").
  final String? themeTitleFontFamily;
  final int? themeTitleFontWeight;
  final double? themeTitleLetterSpacing;
  final bool themeTitleUppercase;

  /// An alternate title color distinct from [themeAccentHex] — only
  /// Post-apocalíptico uses this today (a desaturated tone, since its
  /// vívid accent would look wrong on a title).
  final String? themeTitleColorHex;

  /// Which background texture (V2 §4a) this world's "in-world" screens
  /// (scene, character sheet) render — one of `radial_warm`/`fog`/
  /// `hard_diagonal`/`scanline`/`grain`, or `null` for the app's default
  /// radial treatment. Parsed into `WorldTextureKind` by
  /// `lib/app/design/world_theme.dart`, same reason hex strings are used
  /// for colors above (`core/` stays Flutter-free).
  final String? themeTexture;

  CharacterOrigin originById(String id) => origins.firstWhere(
        (o) => o.id == id,
        orElse: () => throw ArgumentError('unknown origin: $id'),
      );

  /// Same lookup as [originById], but degrades to `null` instead of
  /// throwing — for reading back the chosen origin's own seed content at
  /// `start()` time, where `character.originId` may be `null` (a world with
  /// no chargen at all) or, in principle, stale.
  CharacterOrigin? originByIdOrNull(String? id) {
    if (id == null) return null;
    for (final origin in origins) {
      if (origin.id == id) return origin;
    }
    return null;
  }

  Vow vowById(String id) => vows.firstWhere(
        (v) => v.id == id,
        orElse: () => throw ArgumentError('unknown vow: $id'),
      );

  /// Non-throwing, like [originByIdOrNull] — [id] may be `null` (a world
  /// with no chargen at all) or, in principle, stale.
  Vow? vowByIdOrNull(String? id) {
    if (id == null) return null;
    for (final vow in vows) {
      if (vow.id == id) return vow;
    }
    return null;
  }

  /// Non-throwing, like [originByIdOrNull] — [id] may be `null` (a world
  /// with no tone step) or, in principle, stale.
  ToneOption? toneByIdOrNull(String? id) {
    if (id == null) return null;
    for (final tone in tones) {
      if (tone.id == id) return tone;
    }
    return null;
  }

  AbstractOpponent opponentById(String id) => opponents.firstWhere(
        (o) => o.id == id,
        orElse: () => throw ArgumentError('unknown opponent: $id'),
      );

  Npc npcById(String id) => npcs.firstWhere(
        (n) => n.id == id,
        orElse: () => throw ArgumentError('unknown npc: $id'),
      );

  /// The description for inventory item [id], or `null` if this world hasn't
  /// declared one — deliberately non-throwing (unlike `npcById`/`vowById`):
  /// an inventory id can come from any `list_add` in the content, and a
  /// missing description should degrade the UI, never crash it.
  ItemDefinition? findItem(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Technique techniqueById(String id) => techniques.firstWhere(
        (t) => t.id == id,
        orElse: () => throw ArgumentError('unknown technique: $id'),
      );

  /// The [RankDefinition] matching [character]'s current level, or `null`
  /// for worlds with no milestone-gated ranks (simple linear [progression]).
  RankDefinition? currentRank(Character character) {
    for (final rank in ranks) {
      if (rank.level == character.level) return rank;
    }
    return null;
  }

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

  /// Mirrors [World.fromJson] key-for-key. Includes `'graph'` for a generic,
  /// correct round trip — callers that store the graph in a separate column
  /// (e.g. `campaign_drafts.graph`) must strip that key themselves rather
  /// than relying on this method to omit it.
  Map<String, dynamic> toJson() => {
        'slug': slug,
        'name': name,
        'theme': theme,
        'tone': tone,
        'system_prompt': systemPrompt,
        'image_style_suffix': imageStyleSuffix,
        'resolution': {
          'default_difficulty': defaultDifficulty,
          'critical_margin': criticalMargin,
          'primary_attribute': primaryAttribute,
          if (attributeKeywords.isNotEmpty)
            'attribute_keywords': attributeKeywords,
          if (intentKeywords.isNotEmpty) 'intent_keywords': intentKeywords,
          if (riskKeywords.isNotEmpty) 'risk_keywords': riskKeywords,
          if (selfGrantPatterns.isNotEmpty)
            'self_grant_patterns': selfGrantPatterns,
        },
        'progression': progression.toJson(),
        if (resourceFormulas.isNotEmpty)
          'resources': resourceFormulas.map(
            (key, formula) => MapEntry(key, formula.toJson()),
          ),
        if (meterDefinitions.isNotEmpty)
          'meters': meterDefinitions.map(
            (key, definition) => MapEntry(key, definition.toJson()),
          ),
        if (attributeKeys.isNotEmpty) 'attributes': attributeKeys,
        if (origins.isNotEmpty)
          'origins': [for (final o in origins) o.toJson()],
        if (vows.isNotEmpty) 'vows': [for (final v in vows) v.toJson()],
        if (tones.isNotEmpty) 'tones': [for (final t in tones) t.toJson()],
        if (ranks.isNotEmpty) 'ranks': [for (final r in ranks) r.toJson()],
        if (opponents.isNotEmpty)
          'opponents': [for (final o in opponents) o.toJson()],
        if (npcs.isNotEmpty) 'npcs': [for (final n in npcs) n.toJson()],
        if (techniques.isNotEmpty)
          'techniques': [for (final t in techniques) t.toJson()],
        if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
        if (places.isNotEmpty) 'places': [for (final p in places) p.toJson()],
        if (terms.isNotEmpty) 'terms': [for (final t in terms) t.toJson()],
        if (characterTags.isNotEmpty)
          'character_tags': [for (final c in characterTags) c.toJson()],
        if (storyGraph != null) 'graph': storyGraph!.toJson(),
        'starting_character': _characterToJson(startingCharacter),
        'seed': {
          'narration': seedNarration,
          if (seedChoices.isNotEmpty) 'choices': seedChoices,
          if (personalItemSeedHook != null)
            'personal_item_hook': personalItemSeedHook,
        },
        'ai_runtime_required': aiRuntimeRequired,
        'free_text_actions': allowFreeText,
        if (catalogDescription != null)
          'catalog_description': catalogDescription,
        if (estimatedDurationMinutes != null)
          'estimated_duration_minutes': estimatedDurationMinutes,
        if (contentWarning != null) 'content_warning': contentWarning,
        'relationship_magnitude_cap': relationshipMagnitudeCap,
        'relationship_min': relationshipMin,
        'relationship_max': relationshipMax,
        'chargen_free_attribute_point': hasFreeAttributePoint,
        'chargen_vow_label': chargenVowLabel,
        'chargen_customizable_name': hasCustomizableName,
        if (themeAccentHex != null) 'theme_accent': themeAccentHex,
        if (themeBaseHex != null) 'theme_base': themeBaseHex,
        if (themeSecondaryHex != null) 'theme_secondary': themeSecondaryHex,
        if (themeTitleFontFamily != null)
          'theme_title_font': themeTitleFontFamily,
        if (themeTitleFontWeight != null)
          'theme_title_weight': themeTitleFontWeight,
        if (themeTitleLetterSpacing != null)
          'theme_title_tracking': themeTitleLetterSpacing,
        if (themeTitleUppercase) 'theme_title_uppercase': themeTitleUppercase,
        if (themeTitleColorHex != null)
          'theme_title_color': themeTitleColorHex,
        if (themeTexture != null) 'theme_texture': themeTexture,
      };

  static Map<String, dynamic> _characterToJson(Character character) => {
        'name': character.name,
        'level': character.level,
        'exp': character.exp,
        if (character.attributes.isNotEmpty) 'attributes': character.attributes,
        if (character.resources.isNotEmpty) 'resources': character.resources,
      };

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
      intentKeywords: _keywordsFromJson(resolution['intent_keywords']),
      riskKeywords: _keywordsFromJson(resolution['risk_keywords']),
      selfGrantPatterns: _stringList(resolution['self_grant_patterns']),
      progression: Progression.fromJson(
        (json['progression'] as Map?)?.cast<String, dynamic>(),
      ),
      resourceFormulas: resourceFormulas,
      meterDefinitions: meterDefinitions,
      attributeKeys: _stringList(json['attributes']),
      origins: _originsFromJson(json['origins']),
      vows: _vowsFromJson(json['vows']),
      tones: _tonesFromJson(json['tones']),
      ranks: _ranksFromJson(json['ranks']),
      opponents: _opponentsFromJson(json['opponents']),
      npcs: _npcsFromJson(json['npcs']),
      techniques: _techniquesFromJson(json['techniques']),
      items: _itemsFromJson(json['items']),
      places: _placesFromJson(json['places']),
      terms: _termsFromJson(json['terms']),
      characterTags: _characterTagsFromJson(json['character_tags']),
      storyGraph: json['graph'] is Map
          ? StoryGraph.fromJson((json['graph'] as Map).cast<String, dynamic>())
          : null,
      startingCharacter: _characterFromJson(
        (json['starting_character'] as Map).cast<String, dynamic>(),
        resourceFormulas: resourceFormulas,
        meterDefinitions: meterDefinitions,
      ),
      seedNarration: seed['narration'] as String? ?? '',
      seedChoices: _stringList(seed['choices']),
      personalItemSeedHook: seed['personal_item_hook'] as String?,
      aiRuntimeRequired: json['ai_runtime_required'] as bool? ?? true,
      allowFreeText: json['free_text_actions'] as bool? ?? true,
      catalogDescription: json['catalog_description'] as String?,
      estimatedDurationMinutes:
          (json['estimated_duration_minutes'] as num?)?.toInt(),
      contentWarning: json['content_warning'] as String?,
      relationshipMagnitudeCap:
          (json['relationship_magnitude_cap'] as num?)?.toInt() ?? 1,
      relationshipMin: (json['relationship_min'] as num?)?.toInt() ?? -2,
      relationshipMax: (json['relationship_max'] as num?)?.toInt() ?? 3,
      hasFreeAttributePoint:
          json['chargen_free_attribute_point'] as bool? ?? true,
      chargenVowLabel: json['chargen_vow_label'] as String? ?? 'Juramento',
      hasCustomizableName: json['chargen_customizable_name'] as bool? ?? true,
      themeAccentHex: json['theme_accent'] as String?,
      themeBaseHex: json['theme_base'] as String?,
      themeSecondaryHex: json['theme_secondary'] as String?,
      themeTitleFontFamily: json['theme_title_font'] as String?,
      themeTitleFontWeight: (json['theme_title_weight'] as num?)?.toInt(),
      themeTitleLetterSpacing: (json['theme_title_tracking'] as num?)?.toDouble(),
      themeTitleUppercase: json['theme_title_uppercase'] as bool? ?? false,
      themeTitleColorHex: json['theme_title_color'] as String?,
      themeTexture: json['theme_texture'] as String?,
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

  static List<CharacterOrigin> _originsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          CharacterOrigin.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<Vow> _vowsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          Vow.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<ToneOption> _tonesFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          ToneOption.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<RankDefinition> _ranksFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          RankDefinition.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<AbstractOpponent> _opponentsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          AbstractOpponent.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<Npc> _npcsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          Npc.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<ItemDefinition> _itemsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          ItemDefinition.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<Technique> _techniquesFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          Technique.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<CodexPlace> _placesFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          CodexPlace.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<CodexTerm> _termsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          CodexTerm.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }

  static List<CharacterTagRule> _characterTagsFromJson(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          CharacterTagRule.fromJson((item as Map).cast<String, dynamic>()),
      ];
    }
    return const [];
  }
}
