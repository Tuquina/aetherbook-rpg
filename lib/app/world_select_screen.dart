import 'package:flutter/material.dart';

import '../core/state/character.dart';
import '../core/state/game_session.dart';
import '../core/world/world.dart';
import 'codex_screen.dart';
import 'create_story_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'game_controller.dart';
import 'profile_screen.dart';
import 'story_module_screen.dart';
import 'story_navigation.dart';
import 'widgets/atmosphere.dart';
import 'widgets/confirm_sheet.dart';

/// The stories offered in the menu (GDD §9). Adding a new campaign means
/// adding its slug here once its content JSON exists in `assets/worlds/` —
/// everything shown about it (name, tone, whether it's curated) is always
/// read live from the world itself via [GameController.loadWorldInfo],
/// never duplicated in this list. The 5 freeform genres (Fase 2 — "crea tu
/// propia historia") land in `StoryModule.aiNarrator` automatically, purely
/// from content (no `graph` key in their JSON), same as every other module.
const _availableWorldSlugs = [
  'curated_zombie_01_ultimo_tren',
  'curated_cyberpunk_02_apagon_violeta',
  'xianxia_lianshu',
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

StoryModule _moduleFor(World world) {
  if (world.storyGraph == null) return StoryModule.aiNarrator;
  return world.aiRuntimeRequired ? StoryModule.preArmada : StoryModule.complete;
}

/// Lets the player pick which *type* of story to enter (CLAUDE.md §1:
/// freeform, curada or híbrida modes over the same engine): three module
/// cards, plus a way into the rules (Codex). Picking a module opens
/// [StoryModuleScreen], where the actual campaigns for that type live.
/// Reached from [SplashScreen]'s "Comenzar", and from the back arrow inside
/// a story ([StatusBar.onBack]) — the same [GameController] instance is
/// reused either way, so picking the story already in progress just resumes
/// it.
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
  late final Future<List<World>> _worlds = Future.wait(
    _availableWorldSlugs.map(widget.controller.loadWorldInfo),
  );

  @override
  void initState() {
    super.initState();
    final autoOpen = widget.autoOpenModule;
    if (autoOpen == null) return;
    _worlds.then((worlds) {
      if (!mounted) return;
      final matching = worlds.where((w) => _moduleFor(w) == autoOpen).toList();
      _openModule(autoOpen, matching);
    });
  }

  /// `Future<void>` even though this is wired up as a `ValueChanged<World>`
  /// (`void Function(World)`) callback — Dart allows that assignment since an
  /// async function's return type is compatible with a `void`-returning
  /// function type, and the caller (a story card's `onTap`) has no need to
  /// await it.
  Future<void> _select(World world) async {
    if (!_moduleFor(world).enabled) return;
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

  /// The story left open in memory, if any — the same one the back arrow
  /// already resumes (`_select`'s already-active-session branch). Read once,
  /// synchronously: nothing async changes it while this screen is on top, so
  /// there's no need to listen to [GameController] here just to show it.
  World? get _continuing =>
      widget.controller.isReady ? widget.controller.world : null;

  @override
  Widget build(BuildContext context) {
    final continuing = _continuing;
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(AetherSpace.xl),
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
                        // Only reachable with a real account behind it — the
                        // degraded in-memory mode (auth/settingsPort both
                        // null) has nothing to show in Perfil/Ajustes.
                        if (widget.controller.auth != null &&
                            widget.controller.settingsPort != null)
                          IconButton(
                            onPressed: _openProfile,
                            icon: const Icon(Icons.person_outline_rounded,
                                color: AetherColors.parchmentDim),
                          ),
                      ],
                    ),
                    const SizedBox(height: AetherSpace.lg),
                    // "Retomar es la acción principal, no un botón más" (V2
                    // design prototype §2a) — when a story is already open in
                    // memory, it gets top billing above the module picker
                    // instead of waiting to be found again inside its module.
                    if (continuing != null) ...[
                      _ContinueHero(
                        world: continuing,
                        character: widget.controller.character!,
                        onTap: () => _goToGame(continuing.slug),
                      ),
                      const SizedBox(height: AetherSpace.lg),
                    ],
                    _HowToPlayButton(onTap: _openCodex),
                    const SizedBox(height: AetherSpace.xl),
                    Expanded(
                      child: FutureBuilder<List<World>>(
                        future: _worlds,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'No se pudieron cargar las historias: ${snapshot.error}',
                                style: AetherType.body
                                    .copyWith(color: AetherColors.failure),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          final worlds = snapshot.data;
                          if (worlds == null) {
                            return const Center(child: DestinyWriting());
                          }
                          final byModule = <StoryModule, List<World>>{
                            for (final m in StoryModule.values) m: [],
                          };
                          for (final world in worlds) {
                            byModule[_moduleFor(world)]!.add(world);
                          }
                          return ListView(
                            children: [
                              for (final module in StoryModule.values)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: AetherSpace.md),
                                  child: _ModuleCard(
                                    module: module,
                                    count: byModule[module]!.length,
                                    onTap: () =>
                                        _openModule(module, byModule[module]!),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Dejaste el tomo abierto" (V2 design prototype §2a) — the story left open
/// in memory, given top billing above the module picker instead of making
/// the player re-find it inside its own module. Carries the world's own
/// per-world accent (Stage 6b) rather than a module accent, since at this
/// point it's one specific story, not a category of them.
class _ContinueHero extends StatelessWidget {
  const _ContinueHero({
    required this.world,
    required this.character,
    required this.onTap,
  });

  final World world;
  final Character character;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = WorldTheme.forWorld(world);
    final prog = world.progression;
    return Pressable(
      onTap: onTap,
      child: (pressed) => AnimatedContainer(
        duration: AetherMotion.fast,
        padding: const EdgeInsets.all(AetherSpace.lg),
        decoration: BoxDecoration(
          borderRadius: AetherRadius.allLg,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.accent.withValues(alpha: 0.18), AetherColors.surface],
          ),
          border: Border.all(
            color: theme.accent.withValues(alpha: pressed ? 0.75 : 0.5),
          ),
          boxShadow: pressed ? AetherShadow.glow(theme.accent, strength: 0.2) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: theme.accent.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.play_arrow_rounded, color: theme.accent, size: 24),
            ),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dejaste el tomo abierto',
                      style: AetherType.overline.copyWith(color: theme.accent)),
                  const SizedBox(height: 4),
                  Text(character.name, style: AetherType.title),
                  const SizedBox(height: 2),
                  Text(
                    prog.enabled
                        ? '${world.name} · ${prog.unitLabelCapitalized} ${character.level}'
                        : world.name,
                    style: AetherType.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.accent),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        const SizedBox(width: AetherSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(module.title,
                                        style: AetherType.title
                                            .copyWith(fontSize: 17)),
                                  ),
                                  if (enabled)
                                    _CountPill(
                                        count: widget.count, color: style.accent)
                                  else
                                    const Icon(Icons.lock_outline_rounded,
                                        size: 16,
                                        color: AetherColors.parchmentFaint),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(module.teaser, style: AetherType.caption),
                            ],
                          ),
                        ),
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
