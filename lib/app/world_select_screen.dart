import 'package:flutter/material.dart';

import '../core/state/game_session.dart';
import '../core/world/world.dart';
import 'codex_screen.dart';
import 'create_story_screen.dart';
import 'design/breakpoints.dart';
import 'editor/editor_library_screen.dart';
import 'explorar_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'game_controller.dart';
import 'library_rows.dart';
import 'my_stories_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'story_module_screen.dart';
import 'story_navigation.dart';
import 'widgets/atmosphere.dart';
import 'widgets/confirm_sheet.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/home_sidebar.dart';
import 'widgets/library_thumbnail.dart';

/// The freeform genre worlds offered in the menu (GDD §9) — adding a new one
/// means adding its slug here once its content JSON exists in
/// `assets/worlds/`. The 3 curated/hybrid campaigns
/// (`curated_zombie_01_ultimo_tren`, `curated_cyberpunk_02_apagon_violeta`,
/// `xianxia_lianshu`) migrated out of this list in Admin Stage 5: they're
/// official `campaign_drafts` rows now (author `aetherbook.app@gmail.com`),
/// merged into the catalog dynamically via `listOfficial()` in
/// [_WorldSelectScreenState._loadWorlds] instead of being hardcoded here —
/// their bundled JSON stays on disk purely as a fallback backup, still
/// covered by the content tests that read it directly. Everything shown
/// about a world (name, tone, whether it's curated) is always read live via
/// [GameController.loadWorldInfo], never duplicated in this list. The 5
/// freeform genres (Fase 2 — "crea tu propia historia") land in
/// `StoryModule.aiNarrator` automatically, purely from content (no `graph`
/// key in their JSON), same as every other module.
const _availableWorldSlugs = [
  'isekai',
  'xianxia',
  'superheroes',
  'cyberpunk',
  'postapoc',
];

/// The three story types the menu groups campaigns into (GDD §1: freeform,
/// curated, hybrid — reframed here in player-facing language). Determined
/// from the world's own declared shape, never hardcoded per-slug. Public
/// (unlike the rest of this file's private widgets) because
/// [StoryModuleScreen] needs it too.
enum StoryModule { complete, preArmada, aiNarrator }

extension StoryModuleInfo on StoryModule {
  String get title => switch (this) {
        StoryModule.complete => 'Historias completas',
        StoryModule.preArmada => 'Historias pre-armadas',
        StoryModule.aiNarrator => 'Crea tu propia historia',
      };

  String get description => switch (this) {
        StoryModule.complete =>
          'Una historia ya armada de punta a punta. Tus decisiones eligen el camino, pero cada escena está escrita a mano.',
        StoryModule.preArmada =>
          'Una campaña pre-diseñada, con hitos fijos, que un narrador de IA viste turno a turno según tus elecciones.',
        StoryModule.aiNarrator =>
          'Eliges un género, armas tu personaje y la IA narra lo que sigue turno a turno, sin guion previo. Puedes tener varias historias a la vez.',
      };

  /// The one-line teaser shown on the picker card — a shorter cousin of
  /// [description], which is reserved for the module's own screen.
  String get teaser => switch (this) {
        StoryModule.complete => 'Escrita a mano, de punta a punta.',
        StoryModule.preArmada => 'Rieles fijos, vestidos por IA en vivo.',
        StoryModule.aiNarrator => 'Eliges el género, la IA narra en vivo.',
      };

  /// All three modules are real, playable content.
  bool get enabled => true;
}

/// Purely presentational styling for a module — icon and accent color, kept
/// out of the domain-facing [StoryModuleInfo] extension since it's UI only.
class StoryModuleStyle {
  const StoryModuleStyle({
    required this.icon,
    required this.accent,
    required this.bright,
    required this.glow,
  });

  final IconData icon;
  final Color accent;
  final Color bright;
  final Color glow;
}

StoryModuleStyle storyModuleStyle(StoryModule module) => switch (module) {
      StoryModule.complete => const StoryModuleStyle(
          icon: Icons.auto_stories_rounded,
          accent: AetherColors.ember,
          bright: AetherColors.emberBright,
          glow: AetherColors.emberGlow,
        ),
      StoryModule.preArmada => const StoryModuleStyle(
          icon: Icons.route_rounded,
          accent: AetherColors.arcane,
          bright: AetherColors.arcaneBright,
          glow: AetherColors.arcaneGlow,
        ),
      StoryModule.aiNarrator => const StoryModuleStyle(
          icon: Icons.smart_toy_rounded,
          accent: AetherColors.nova,
          bright: AetherColors.novaBright,
          glow: AetherColors.novaGlow,
        ),
    };

/// Public (unlike the rest of this file's private widgets) — `CharacterSheetSheet`
/// needs it too, for its "world · módulo · turno N" subtitle line.
StoryModule moduleFor(World world) {
  if (world.storyGraph == null) return StoryModule.aiNarrator;
  return world.aiRuntimeRequired ? StoryModule.preArmada : StoryModule.complete;
}

/// The home dashboard (V2 design prototype §8a/§8b/§2a) — reached from
/// [SplashScreen]'s "Comenzar" and from the back arrow inside a story
/// ([StatusBar.onBack]). One screen, three chrome modes decided by width
/// ([AetherBreakpoints]): mobile keeps its original single-column shape
/// (hero + "cómo se juega" + module grid); tablet adds [HomeBottomNav] and a
/// "Sigue leyendo" row; desktop adds [HomeSidebar] instead. The hero and
/// "Sigue leyendo" are both driven by [GameController.storyLibrary] — a real
/// account-wide query, not just whatever session happens to be in memory —
/// so "what did I leave open" survives a fresh launch, not only mid-session
/// back-navigation.
class WorldSelectScreen extends StatefulWidget {
  const WorldSelectScreen({super.key, required this.controller, this.autoOpenModule});

  final GameController controller;

  /// Set once, right after the first-run onboarding flow (V2 §6c-e) hands
  /// off here — immediately opens the module the player tapped on
  /// onboarding's last page, instead of making them tap it again on a screen
  /// they haven't even seen render yet. `null` on every other route into
  /// this screen (splash, the in-story back arrow, chargen's own handoff).
  final StoryModule? autoOpenModule;

  @override
  State<WorldSelectScreen> createState() => _WorldSelectScreenState();
}

class _WorldSelectScreenState extends State<WorldSelectScreen> {
  late final Future<List<World>> _worlds = _loadWorlds();
  late final Future<List<SessionLibraryEntry>> _library = widget.controller.storyLibrary();

  /// Every bundled world plus every *published* official campaign (Admin
  /// Stage 3) — same "Historias completas"/"Historias pre-armadas" catalog,
  /// just sourced from two places now. `listOfficial()` also returns
  /// unpublished drafts to an admin caller (for the editor's own "Oficiales"
  /// review list) — filtered to [CampaignDraftSummary.isPublished] here
  /// because this is the real player-facing catalog: an admin's own
  /// in-progress draft must not show up as playable from the home dashboard,
  /// same as it wouldn't for anyone else. `campaignDrafts` is `null` in the
  /// in-memory-degraded mode — same graceful fallback every other account
  /// feature uses.
  Future<List<World>> _loadWorlds() async {
    final campaignDrafts = widget.controller.campaignDrafts;
    final officialSlugs = campaignDrafts != null
        ? (await campaignDrafts.listOfficial())
            .where((s) => s.isPublished)
            .map((s) => s.slug)
            .toList()
        : const <String>[];
    final slugs = {..._availableWorldSlugs, ...officialSlugs};
    return Future.wait(slugs.map(widget.controller.loadWorldInfo));
  }

  @override
  void initState() {
    super.initState();
    final autoOpen = widget.autoOpenModule;
    if (autoOpen == null) return;
    _worlds.then((worlds) {
      if (!mounted) return;
      final matching = worlds.where((w) => moduleFor(w) == autoOpen).toList();
      _openModule(autoOpen, matching);
    });
  }

  /// `Future<void>` even though this is wired up as a `ValueChanged<World>`
  /// (`void Function(World)`) callback — Dart allows that assignment since an
  /// async function's return type is compatible with a `void`-returning
  /// function type, and the caller (a story card's `onTap`) has no need to
  /// await it.
  Future<void> _select(World world) async {
    if (!moduleFor(world).enabled) return;
    await StoryNavigation.open(context, widget.controller, world);
  }

  void _goToChargen(World world, {bool forceNew = false, bool alwaysCreateNew = false}) {
    StoryNavigation.goToChargen(context, widget.controller, world,
        forceNew: forceNew, alwaysCreateNew: alwaysCreateNew);
  }

  /// Picking a genre on [CreateStoryScreen] always starts a brand-new story
  /// — never resumes or overwrites one already in progress, since a player
  /// can have several active sessions for the same freeform world at once
  /// (CLAUDE.md Fase 2).
  void _selectGenre(World world) =>
      _goToChargen(world, alwaysCreateNew: true);

  /// Resumes one exact saved story from [CreateStoryScreen]'s "tus
  /// historias" list — unlike [_select], never goes through chargen (the
  /// character already exists) and never guesses "the latest" (there can be
  /// several; this one is the one the player tapped).
  Future<void> _resumeStory(GameSessionSummary summary) async {
    await StoryNavigation.resume(context, widget.controller,
        worldSlug: summary.worldSlug, sessionId: summary.id);
  }

  /// Confirms and abandons one saved story — [CreateStoryScreen] awaits this
  /// and reloads its own list once it resolves.
  Future<void> _abandonStory(GameSessionSummary summary) async {
    final confirmed = await showConfirmSheet(
      context,
      title: summary.characterName,
      message: 'Vas a abandonar esta historia. No se puede deshacer.',
      confirmLabel: 'Abandonar',
    );
    if (!confirmed) return;
    await widget.controller.abandonStory(summary.id);
  }

  /// "Reiniciar historia" — abandons whatever session already exists for
  /// [world] (in memory or persisted in Supabase) and starts a clean one, for
  /// a player who wants to play a curated campaign again from the top
  /// instead of always resuming where they left off.
  Future<void> _restart(World world) async {
    final confirmed = await showConfirmSheet(
      context,
      title: world.name,
      message:
          'Vas a reiniciar esta historia desde el principio. El progreso actual se pierde.',
      confirmLabel: 'Reiniciar',
    );
    if (!confirmed || !mounted) return;

    if (world.origins.isNotEmpty) {
      _goToChargen(world, forceNew: true);
    } else {
      await widget.controller.start(world.slug, forceNew: true);
      if (!mounted) return;
      _goToGame(world.slug);
    }
  }

  void _goToGame(String worldSlug) {
    StoryNavigation.goToGame(context, widget.controller, worldSlug);
  }

  void _openModule(StoryModule module, List<World> worlds) {
    if (module == StoryModule.aiNarrator) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateStoryScreen(
            controller: widget.controller,
            worlds: worlds,
            onSelectGenre: _selectGenre,
            onResumeStory: _resumeStory,
            onAbandonStory: _abandonStory,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryModuleScreen(
          module: module,
          worlds: worlds,
          onTap: _select,
          onRestart: _restart,
        ),
      ),
    );
  }

  void _openCodex() => Navigator.of(context).push(CodexScreen.route());

  void _openProfile() {
    final auth = widget.controller.auth;
    final settingsPort = widget.controller.settingsPort;
    if (auth == null || settingsPort == null) return;
    Navigator.of(context).push(ProfileScreen.route(
      controller: widget.controller,
      authPort: auth,
      settingsPort: settingsPort,
    ));
  }

  void _openSettings() {
    final auth = widget.controller.auth;
    final settingsPort = widget.controller.settingsPort;
    if (auth == null || settingsPort == null) return;
    Navigator.of(context).push(SettingsScreen.route(
      controller: widget.controller,
      settingsPort: settingsPort,
      authPort: auth,
    ));
  }

  void _openMyStories(List<World> worlds) {
    Navigator.of(context)
        .push(MyStoriesScreen.route(controller: widget.controller, catalogWorlds: worlds));
  }

  void _openEditor() {
    final campaignDrafts = widget.controller.campaignDrafts;
    if (campaignDrafts == null) return;
    Navigator.of(context).push(
      EditorLibraryScreen.route(
        controller: widget.controller,
        campaignDrafts: campaignDrafts,
      ),
    );
  }

  void _openExplorar() {
    Navigator.of(context).push(ExplorarScreen.route(controller: widget.controller));
  }

  /// What each [HomeNavDestination] does from the home dashboard.
  void _onNavSelect(HomeNavDestination destination, List<World> worlds) {
    switch (destination) {
      case HomeNavDestination.inicio:
        break;
      case HomeNavDestination.misHistorias:
        _openMyStories(worlds);
      case HomeNavDestination.escribir:
        _openEditor();
      case HomeNavDestination.explorar:
        _openExplorar();
      case HomeNavDestination.codice:
        _openCodex();
      case HomeNavDestination.ajustes:
        _openSettings();
    }
  }

  Future<void> _openRow(LibraryRow row) async {
    final entry = row.entry;
    if (entry == null) {
      await StoryNavigation.open(context, widget.controller, row.world);
    } else {
      await StoryNavigation.resume(context, widget.controller,
          worldSlug: entry.worldSlug, sessionId: entry.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: FutureBuilder<List<World>>(
            future: _worlds,
            builder: (context, worldsSnapshot) {
              if (worldsSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AetherSpace.xl),
                    child: Text(
                      'No se pudieron cargar las historias: ${worldsSnapshot.error}',
                      style: AetherType.body.copyWith(color: AetherColors.failure),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final worlds = worldsSnapshot.data;
              if (worlds == null) return const Center(child: DestinyWriting());

              final byModule = <StoryModule, List<World>>{
                for (final m in StoryModule.values) m: [],
              };
              for (final world in worlds) {
                byModule[moduleFor(world)]!.add(world);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= AetherBreakpoints.desktop) {
                    return _buildDesktop(context, worlds, byModule);
                  }
                  if (constraints.maxWidth >= AetherBreakpoints.tablet) {
                    return _buildTablet(context, worlds, byModule);
                  }
                  return _buildMobile(context, worlds, byModule);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobile(
    BuildContext context,
    List<World> worlds,
    Map<StoryModule, List<World>> byModule,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AetherSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Elige tu historia', style: AetherType.display),
                        const SizedBox(height: AetherSpace.xs),
                        Text('Cada mundo se escribe distinto.',
                            style: AetherType.body
                                .copyWith(color: AetherColors.parchmentDim, fontSize: 15)),
                      ],
                    ),
                  ),
                  // Phone width has no persistent nav chrome at all (unlike
                  // tablet's HomeBottomNav/desktop's HomeSidebar), so
                  // "Escribir" needs its own inline entry point here too —
                  // same account guard as the profile icon below.
                  if (widget.controller.campaignDrafts != null)
                    IconButton(
                      onPressed: _openEditor,
                      icon: const Icon(Icons.edit_note_outlined, color: AetherColors.parchmentDim),
                      tooltip: 'Escribir una historia',
                    ),
                  // Only reachable with a real account behind it — the
                  // degraded in-memory mode (auth/settingsPort both null)
                  // has nothing to show in Perfil/Ajustes.
                  if (widget.controller.auth != null && widget.controller.settingsPort != null)
                    IconButton(
                      onPressed: _openProfile,
                      icon: const Icon(Icons.person_outline_rounded, color: AetherColors.parchmentDim),
                    ),
                ],
              ),
              const SizedBox(height: AetherSpace.lg),
              FutureBuilder<List<SessionLibraryEntry>>(
                future: _library,
                builder: (context, librarySnapshot) {
                  final entries = librarySnapshot.data ?? const [];
                  final rows = buildLibraryRows(catalogWorlds: worlds, entries: entries);
                  final active = rows.where((r) => r.entry?.status == 'active').toList();
                  final storyCount = entries.where((e) => e.status != 'abandoned').length;
                  void startNew() =>
                      _openModule(StoryModule.complete, byModule[StoryModule.complete]!);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (active.isEmpty)
                        _StartHero(onTap: startNew)
                      else ...[
                        _ContinueHero(row: active.first, onResume: () => _openRow(active.first)),
                        const SizedBox(height: AetherSpace.sm),
                        _HeroButton(
                          label: 'Empezar una historia nueva',
                          icon: Icons.add_rounded,
                          filled: false,
                          fullWidth: true,
                          accent: WorldTheme.forWorld(active.first.world).accent,
                          onTap: startNew,
                        ),
                      ],
                      const SizedBox(height: AetherSpace.md),
                      _MyStoriesButton(
                        count: storyCount,
                        onTap: () => _openMyStories(worlds),
                      ),
                      const SizedBox(height: AetherSpace.lg),
                    ],
                  );
                },
              ),
              _HowToPlayButton(onTap: _openCodex),
              const SizedBox(height: AetherSpace.xl),
              Expanded(
                child: ListView(
                  children: [
                    for (final module in StoryModule.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AetherSpace.md),
                        child: _ModuleCard(
                          module: module,
                          count: byModule[module]!.length,
                          onTap: () => _openModule(module, byModule[module]!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablet(
    BuildContext context,
    List<World> worlds,
    Map<StoryModule, List<World>> byModule,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AetherSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Aetherbook',
                          style: AetherType.display.copyWith(fontSize: 20, color: AetherColors.goldBright)),
                      const Spacer(),
                      if (widget.controller.auth != null && widget.controller.settingsPort != null)
                        IconButton(
                          onPressed: _openProfile,
                          icon: const Icon(Icons.person_outline_rounded, color: AetherColors.parchmentDim),
                        ),
                    ],
                  ),
                  const SizedBox(height: AetherSpace.lg),
                  _homeBody(worlds, byModule, crossAxisCount: 2),
                ],
              ),
            ),
          ),
        ),
        HomeBottomNav(
          current: HomeNavDestination.inicio,
          onSelect: (d) => _onNavSelect(d, worlds),
        ),
      ],
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    List<World> worlds,
    Map<StoryModule, List<World>> byModule,
  ) {
    final auth = widget.controller.auth;
    final email = auth?.email;
    return Row(
      children: [
        FutureBuilder<List<SessionLibraryEntry>>(
          future: _library,
          builder: (context, librarySnapshot) {
            final entries = librarySnapshot.data ?? const [];
            final counts = <String, int>{};
            for (final e in entries) {
              if (e.status == 'abandoned') continue;
              counts.update(e.worldSlug, (v) => v + 1, ifAbsent: () => 1);
            }
            return HomeSidebar(
              current: HomeNavDestination.inicio,
              onSelect: (d) => _onNavSelect(d, worlds),
              worlds: [
                for (final w in worlds)
                  HomeWorldEntry(
                    name: w.name,
                    accent: WorldTheme.forWorld(w).accent,
                    count: counts[w.slug] ?? 0,
                  ),
              ],
              accountInitial: email != null && email.isNotEmpty ? email[0].toUpperCase() : '?',
              accountName: email ?? 'Jugador',
              accountSubtitle: '${entries.where((e) => e.status != 'abandoned').length} tomos',
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AetherSpace.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: _homeBody(worlds, byModule, crossAxisCount: 3),
            ),
          ),
        ),
      ],
    );
  }

  /// Shared body for tablet/desktop: hero, "Sigue leyendo", "Si quieres
  /// empezar algo" — only the surrounding chrome (bottom nav vs sidebar)
  /// differs between the two.
  Widget _homeBody(
    List<World> worlds,
    Map<StoryModule, List<World>> byModule, {
    required int crossAxisCount,
  }) {
    return FutureBuilder<List<SessionLibraryEntry>>(
      future: _library,
      builder: (context, librarySnapshot) {
        final rows = buildLibraryRows(
          catalogWorlds: worlds,
          entries: librarySnapshot.data ?? const [],
        );
        final active = rows.where((r) => r.entry?.status == 'active').toList();
        final hero = active.isNotEmpty ? active.first : null;
        final unstarted = rows.where((r) => r.entry == null).toList();
        final carousel = [...active.skip(1), ...unstarted].take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hero != null) ...[
              _ContinueHero(row: hero, onResume: () => _openRow(hero)),
              const SizedBox(height: AetherSpace.sm),
              _HeroButton(
                label: 'Empezar una historia nueva',
                icon: Icons.add_rounded,
                filled: false,
                fullWidth: true,
                accent: WorldTheme.forWorld(hero.world).accent,
                onTap: () => _openModule(StoryModule.complete, byModule[StoryModule.complete]!),
              ),
              const SizedBox(height: AetherSpace.xl),
            ] else ...[
              _StartHero(
                onTap: () => _openModule(StoryModule.complete, byModule[StoryModule.complete]!),
              ),
              const SizedBox(height: AetherSpace.xl),
            ],
            if (carousel.isNotEmpty) ...[
              Row(
                children: [
                  // Expanded + ellipsis: at a large OS text-scale setting,
                  // "Sigue leyendo" plus the "Ver todos" button no longer
                  // both fit this Row's natural width on a tablet's
                  // narrower content column (V2 Stage 8) -- the title gives
                  // way, the action button never does.
                  Expanded(
                    child: Text('Sigue leyendo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AetherType.title),
                  ),
                  const SizedBox(width: AetherSpace.sm),
                  TextButton(
                    onPressed: () => _openMyStories(worlds),
                    child: const Text('Ver todos', style: TextStyle(color: AetherColors.goldBright)),
                  ),
                ],
              ),
              const SizedBox(height: AetherSpace.sm),
              GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AetherSpace.sm,
                crossAxisSpacing: AetherSpace.sm,
                childAspectRatio: 2.6,
                children: [
                  for (final row in carousel)
                    _LibraryListTile(row: row, onTap: () => _openRow(row)),
                ],
              ),
              const SizedBox(height: AetherSpace.xl),
            ],
            Text('Si quieres empezar algo', style: AetherType.title),
            const SizedBox(height: AetherSpace.sm),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AetherSpace.sm,
              crossAxisSpacing: AetherSpace.sm,
              // The title now wraps to 2 lines instead of ellipsizing (V2
              // Stage 8 follow-up -- "Historias comp..." was illegible). A
              // fixed aspect ratio can't grow to fit that second line at a
              // large OS text-scale setting, especially on the narrower
              // desktop columns (crossAxisCount 3), so the ratio itself
              // shrinks (taller cards) as text-scale grows.
              childAspectRatio:
                  _moduleCardAspectRatio(MediaQuery.textScalerOf(context).scale(1.0), crossAxisCount),
              children: [
                for (final module in StoryModule.values)
                  _ModuleCard(
                    module: module,
                    count: byModule[module]!.length,
                    onTap: () => _openModule(module, byModule[module]!),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// "Dejaste el tomo abierto" (V2 design prototype §2a/§8a/§8b, restyled
/// after §2b's "Tres tomos abiertos" hero) — the account's most recently
/// played active session, from [GameController.storyLibrary] rather than
/// whatever happens to be in memory, so it survives a fresh launch. A real
/// hero, not a compact pill: the latest turn's scene image as a background
/// (falling back to a gradient wash in the world's own accent — Stage 6b —
/// when there isn't one yet), the session's own title, a 2-line quote from
/// the latest narration, and one action inside the card itself
/// ([onResume], "Retomar el turno N") — "Empezar una historia nueva" used to
/// share this Wrap but now renders as its own full-width button right below
/// the card (both callers do this identically), so the tome and "start
/// something else" read as two separate, equally-weighted actions instead of
/// one crowded footer.
class _ContinueHero extends StatelessWidget {
  const _ContinueHero({required this.row, required this.onResume});

  final LibraryRow row;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final world = row.world;
    final entry = row.entry!; // only ever built for a row with an active session
    final theme = WorldTheme.forWorld(world);
    final title = entry.title?.trim().isNotEmpty == true ? entry.title!.trim() : world.name;
    final quote = entry.lastNarration?.trim();
    final imageUrl = entry.imageUrl;
    // The bottom of the gradient used to fade to flat void_ regardless of
    // which world this is — now it blends in the world/module's own accent
    // so the card visibly belongs to "its" color, not a neutral wash.
    final tintedDark = Color.alphaBlend(theme.accent.withValues(alpha: 0.38), AetherColors.void_);

    return ClipRRect(
      borderRadius: AetherRadius.allLg,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: theme.accent.withValues(alpha: 0.5))),
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      key: ValueKey(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _HeroFallback(accent: theme.accent),
                    )
                  : _HeroFallback(accent: theme.accent),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, tintedDark.withValues(alpha: 0.94)],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AetherSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Dejaste el tomo abierto'.toUpperCase(),
                      style: AetherType.overline.copyWith(color: theme.accent)),
                  const SizedBox(height: AetherSpace.sm),
                  Text(title, style: AetherType.display.copyWith(fontSize: 26)),
                  if (quote != null && quote.isNotEmpty) ...[
                    const SizedBox(height: AetherSpace.sm),
                    Text('«$quote»',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AetherType.body.copyWith(
                            fontStyle: FontStyle.italic, color: AetherColors.parchmentDim)),
                  ],
                  const SizedBox(height: AetherSpace.lg),
                  _HeroButton(
                    label: 'Retomar el turno ${entry.turnCount}',
                    icon: Icons.play_arrow_rounded,
                    filled: true,
                    accent: theme.accent,
                    onTap: onResume,
                  ),
                  const SizedBox(height: AetherSpace.sm),
                  Text('${world.name} · ${relativeTimeLabel(entry.updatedAt)}',
                      style: AetherType.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of [_ContinueHero] when the account has no active session
/// at all — same container/format (V2's own consistency point: no ad-hoc
/// "smaller" empty state), a neutral gold/ink wash rather than any one
/// world's accent (there's no "current" world in this state), and a single
/// CTA into "Historia completa" — the same destination [_ContinueHero]'s
/// own "Empezar una historia nueva" uses, your call.
class _StartHero extends StatelessWidget {
  const _StartHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AetherRadius.allLg,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AetherColors.gold.withValues(alpha: 0.4)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AetherColors.goldGlow, AetherColors.surface],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AetherSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Empieza tu historia'.toUpperCase(),
                  style: AetherType.overline.copyWith(color: AetherColors.goldBright)),
              const SizedBox(height: AetherSpace.sm),
              Text('Todavía no abriste ningún tomo',
                  style: AetherType.display.copyWith(fontSize: 24)),
              const SizedBox(height: AetherSpace.sm),
              Text(
                'Elige un mundo y escribe tu primer capítulo. Cuando vuelvas, todo sigue '
                'donde lo dejaste.',
                style: AetherType.body.copyWith(color: AetherColors.parchmentDim, fontSize: 13.5),
              ),
              const SizedBox(height: AetherSpace.lg),
              _HeroButton(
                label: 'Empezar una historia',
                icon: Icons.auto_stories_rounded,
                filled: true,
                accent: AetherColors.gold,
                onTap: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [_ContinueHero]'s background when its session has no scene image yet
/// (a curated, AI-free world, or a session whose first turn hasn't
/// generated one) — the accent-to-surface wash the hero always used before
/// this rebuild, now demoted to a fallback rather than the only treatment.
class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.22), AetherColors.surface],
        ),
      ),
    );
  }
}

/// One of [_ContinueHero]/[_StartHero]'s CTAs — [filled] true is the
/// primary action (solid accent wash), false is secondary (outline only).
/// [fullWidth] stretches the button to fill its parent — used when this CTA
/// stands on its own outside the hero card (e.g. "Empezar una historia
/// nueva" below [_ContinueHero]) instead of sharing a `Wrap` with a sibling.
class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.accent,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final Color accent;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: (pressed) => AnimatedContainer(
        duration: AetherMotion.fast,
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.md),
        decoration: BoxDecoration(
          color: filled
              ? accent.withValues(alpha: pressed ? 0.32 : 0.22)
              : (pressed ? AetherColors.surfaceRaised : null),
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: accent.withValues(alpha: filled ? 0.75 : 0.4)),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: filled ? accent : AetherColors.parchmentDim),
            const SizedBox(width: 6),
            Text(
              label,
              style: AetherType.label.copyWith(
                fontSize: 13,
                fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                color: filled ? accent : AetherColors.parchmentDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width "Mis historias" entry point for the mobile home dashboard
/// (V2 §2b's unified library, reframed here as a link rather than an inline
/// list — [MyStoriesScreen] already *is* "every story you started"). Tablet
/// and desktop reach the same screen through [HomeBottomNav]/[HomeSidebar]
/// instead; this button exists because the phone layout has no persistent
/// nav chrome to carry that destination.
class _MyStoriesButton extends StatefulWidget {
  const _MyStoriesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  State<_MyStoriesButton> createState() => _MyStoriesButtonState();
}

class _MyStoriesButtonState extends State<_MyStoriesButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final plural = widget.count == 1 ? 'tomo' : 'tomos';
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: AetherMotion.fast,
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: AetherSpace.lg, vertical: AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allPill,
            border: Border.all(
              color: _pressed
                  ? AetherColors.gold.withValues(alpha: 0.6)
                  : AetherColors.hairlineStrong,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_stories_rounded, color: AetherColors.goldSoft, size: 17),
              const SizedBox(width: AetherSpace.sm),
              Text(
                widget.count > 0
                    ? 'Mis historias · ${widget.count} $plural'
                    : 'Mis historias',
                style: AetherType.label.copyWith(color: AetherColors.goldSoft, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact row for "Sigue leyendo"'s carousel/grid — world accent dot,
/// title, and either "turno N" or "sin empezar".
class _LibraryListTile extends StatelessWidget {
  const _LibraryListTile({required this.row, required this.onTap});

  final LibraryRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = WorldTheme.forWorld(row.world).accent;
    final entry = row.entry;
    final title = entry?.title?.trim().isNotEmpty == true ? entry!.title! : row.world.name;
    final subtitle = entry == null
        ? 'Sin empezar'
        : '${entry.characterName} · turno ${entry.turnCount}';
    final progress = row.progress;
    return Pressable(
      onTap: onTap,
      child: (pressed) => AnimatedContainer(
        duration: AetherMotion.fast,
        padding: const EdgeInsets.all(AetherSpace.sm),
        decoration: BoxDecoration(
          color: pressed ? AetherColors.surfaceRaised : AetherColors.surface,
          borderRadius: AetherRadius.allMd,
          border: Border.all(color: accent.withValues(alpha: entry == null ? 0.16 : 0.3)),
        ),
        child: Row(
          children: [
            LibraryThumbnail(imageUrl: entry?.imageUrl, accent: accent, size: 40),
            const SizedBox(width: AetherSpace.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AetherType.label.copyWith(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: AetherType.caption.copyWith(fontSize: 10.5)),
                  if (progress != null) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: AetherRadius.allPill,
                      child: SizedBox(
                        height: 3,
                        child: Stack(children: [
                          Container(color: AetherColors.void_),
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(color: accent),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width secondary affordance into [CodexScreen] — one of the three
/// things this screen must surface per spec, sitting above the module cards
/// so it reads as a peer action, not a buried settings link.
class _HowToPlayButton extends StatefulWidget {
  const _HowToPlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_HowToPlayButton> createState() => _HowToPlayButtonState();
}

class _HowToPlayButtonState extends State<_HowToPlayButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: AetherMotion.fast,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: AetherSpace.lg, vertical: AetherSpace.md),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allPill,
            border: Border.all(
              color: _pressed
                  ? AetherColors.gold.withValues(alpha: 0.6)
                  : AetherColors.hairlineStrong,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.menu_book_rounded,
                  color: AetherColors.goldSoft, size: 17),
              const SizedBox(width: AetherSpace.sm),
              Text('Cómo se juega',
                  style: AetherType.label.copyWith(
                      color: AetherColors.goldSoft, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three story-type tiles. Shows the module's icon, title,
/// teaser and how many campaigns live inside it; dims and shows a lock when
/// the module isn't playable yet.
/// Card grows taller (smaller ratio) as text-scale grows, more aggressively
/// on the narrower desktop columns -- see the comment at the grid's
/// `childAspectRatio` call site.
double _moduleCardAspectRatio(double textScale, int crossAxisCount) {
  if (textScale <= 1.0) return 1.6;
  final narrowPenalty = crossAxisCount >= 3 ? 0.55 : 0.35;
  final ratio = 1.6 - (textScale - 1.0) * narrowPenalty;
  return ratio.clamp(1.05, 1.6);
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    required this.module,
    required this.count,
    required this.onTap,
  });

  final StoryModule module;
  final int count;
  final VoidCallback onTap;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final style = storyModuleStyle(module);
    final enabled = module.enabled;
    return GestureDetector(
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: AetherMotion.fast,
        curve: AetherMotion.standard,
        child: AnimatedContainer(
          duration: AetherMotion.fast,
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allLg,
            border: Border.all(
              color: enabled
                  ? style.accent.withValues(alpha: _pressed ? 0.7 : 0.4)
                  : AetherColors.hairline,
            ),
            boxShadow: (enabled && _pressed)
                ? AetherShadow.glow(style.accent, strength: 0.22)
                : null,
          ),
          // The color+gradient accent wash is a separate layer on top of the
          // opaque card fill above — a BoxDecoration can't hold both a solid
          // `color` and a fading `gradient` at once (the gradient's shader
          // replaces the fill outright, so its transparent end would show
          // the screen behind the card instead of staying opaque).
          child: ClipRRect(
            borderRadius: AetherRadius.allLg,
            child: Stack(
              children: [
                if (enabled)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [style.glow, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AetherSpace.lg),
                  child: Opacity(
                    opacity: enabled ? 1 : 0.6,
                    // The title used to share its row with the icon and the
                    // count pill, squeezed down to one ellipsized line on
                    // anything narrower than a full-width phone list (the
                    // 2-column tablet grid, mainly — "Historias comp...").
                    // Icon and pill now sit on their own header row, so the
                    // title gets the card's full width to wrap into instead:
                    // "Historias / completas", never a mid-word cut.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: style.accent
                                    .withValues(alpha: enabled ? 0.16 : 0.08),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: style.accent.withValues(alpha: 0.5)),
                              ),
                              child: Icon(style.icon,
                                  color: enabled ? style.bright : style.accent,
                                  size: 22),
                            ),
                            const Spacer(),
                            if (enabled)
                              _CountPill(count: widget.count, color: style.accent)
                            else
                              const Icon(Icons.lock_outline_rounded,
                                  size: 16, color: AetherColors.parchmentFaint),
                          ],
                        ),
                        const SizedBox(height: AetherSpace.sm),
                        Text(module.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AetherType.title.copyWith(fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(module.teaser,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AetherType.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final plural = count == 1 ? 'historia' : 'historias';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AetherRadius.allPill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text('$count $plural',
          style: AetherType.overline.copyWith(
              color: color, fontSize: 9.5, letterSpacing: 0.6)),
    );
  }
}
