/// How hard the world pushes back on a failed check (V2 design prototype
/// §6b: "Dureza del mundo"). Applied as a flat offset to every difficulty
/// number the engine resolves against (`ResolvePlayerAction`/
/// `ResolveStoryChoice`) — never changes which attribute is rolled, never
/// touches content, just how forgiving the band thresholds are.
enum WorldHarshness {
  indulgente(-2),
  justo(0),
  cruel(2);

  const WorldHarshness(this.difficultyOffset);

  /// Added to the difficulty every check resolves against. Negative makes
  /// checks easier (indulgente), positive makes them harder (cruel).
  final int difficultyOffset;

  static WorldHarshness fromWire(String? raw) {
    return WorldHarshness.values.firstWhere(
      (h) => h.name == raw,
      orElse: () => WorldHarshness.justo,
    );
  }
}

/// One selectable entry in the "temas que el narrador evita" catalog
/// (V2 design prototype §6b) — a fixed, curated list rather than free text,
/// so the narrator prompt instruction stays a closed, reviewable set.
class AvoidedTheme {
  const AvoidedTheme({required this.id, required this.label});

  final String id;
  final String label;
}

/// Account-wide player preferences (V2 design prototype §6b) plus the
/// first-run onboarding flag (§6c-e) — one value per account, synced via
/// `SettingsPort`, never per-session. Everything here either changes how the
/// game is *presented* (text size, typewriter effect, illustrate scenes,
/// show the roll) or is a real input to the engine/narrator
/// ([worldHarshness]/[avoidedThemes]) — nothing here is cosmetic-only that
/// pretends to be functional.
class UserSettings {
  const UserSettings({
    this.textScale = 1.0,
    this.typewriterEffect = true,
    this.illustrateScenes = true,
    this.worldHarshness = WorldHarshness.justo,
    this.suggestActions = true,
    this.showTheRoll = true,
    this.avoidedThemes = const [],
    this.reminderFrequency = 'weekly',
    this.hasSeenOnboarding = false,
  });

  /// Multiplier applied on top of the narration text style's base font size.
  /// `1.0` is the default the app already ships with; the mockup's slider
  /// range is roughly `0.8`..`1.3`.
  final double textScale;

  /// Whether narration reveals letter-by-letter as it's read, or appears at
  /// once — a presentation-only preference, no engine effect.
  final bool typewriterEffect;

  /// Whether the app asks for a scene illustration at all — off skips the
  /// image-generation call entirely for every turn, not just its display.
  final bool illustrateScenes;

  final WorldHarshness worldHarshness;

  /// Whether a freeform world's narrator is asked for `suggested_choices` at
  /// all — off means the player only ever writes free text, even in a world
  /// that would otherwise offer quick options.
  final bool suggestActions;

  /// Whether the resolved dice check (`FateRoll`) renders during play, or
  /// the outcome only arrives narrated in prose.
  final bool showTheRoll;

  /// Ids from [avoidedThemeCatalog] the narrator must not depict — reaches
  /// the narrator prompt as a non-negotiable instruction.
  final List<String> avoidedThemes;

  /// How often to remind the player of an open story. Stored for later use —
  /// no notification is actually scheduled yet (no push-notification infra
  /// exists), see `V2_IMPLEMENTATION_PLAN.md`'s Stage on this.
  final String reminderFrequency;

  /// Whether this account has completed (or skipped) the first-run
  /// onboarding flow — `false` for every account until it has, `true` after,
  /// forever. Gates whether `SplashScreen` routes a freshly-authenticated
  /// account through onboarding before `WorldSelectScreen`.
  final bool hasSeenOnboarding;

  /// The fixed, curated set of themes a player can ask the narrator to
  /// avoid (V2 design prototype §6b) — a closed list, not free text, so the
  /// resulting prompt instruction stays reviewable.
  static const avoidedThemeCatalog = [
    AvoidedTheme(id: 'violencia_grafica', label: 'Violencia gráfica explícita'),
    AvoidedTheme(id: 'contenido_sexual', label: 'Contenido sexual'),
    AvoidedTheme(
      id: 'muerte_personajes_queridos',
      label: 'Muerte de personajes que el jugador cuida',
    ),
    AvoidedTheme(id: 'autolesion', label: 'Autolesión o suicidio'),
    AvoidedTheme(id: 'terror_corporal', label: 'Terror corporal'),
    AvoidedTheme(id: 'crueldad_animal', label: 'Crueldad animal'),
  ];

  /// [avoidedThemes] resolved to their human-readable labels — what
  /// actually reaches the narrator prompt (`NarratorRequest.avoidedThemes`),
  /// since the wire only needs text to instruct with, not ids.
  List<String> get avoidedThemeLabels => [
        for (final theme in avoidedThemeCatalog)
          if (avoidedThemes.contains(theme.id)) theme.label,
      ];

  UserSettings copyWith({
    double? textScale,
    bool? typewriterEffect,
    bool? illustrateScenes,
    WorldHarshness? worldHarshness,
    bool? suggestActions,
    bool? showTheRoll,
    List<String>? avoidedThemes,
    String? reminderFrequency,
    bool? hasSeenOnboarding,
  }) {
    return UserSettings(
      textScale: textScale ?? this.textScale,
      typewriterEffect: typewriterEffect ?? this.typewriterEffect,
      illustrateScenes: illustrateScenes ?? this.illustrateScenes,
      worldHarshness: worldHarshness ?? this.worldHarshness,
      suggestActions: suggestActions ?? this.suggestActions,
      showTheRoll: showTheRoll ?? this.showTheRoll,
      avoidedThemes: avoidedThemes ?? this.avoidedThemes,
      reminderFrequency: reminderFrequency ?? this.reminderFrequency,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }
}
