import 'package:flutter/material.dart';

import '../core/world/world.dart';
import 'chargen_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'widgets/atmosphere.dart';

/// The stories offered in the menu (GDD §9). Adding a new campaign means
/// adding its slug here once its content JSON exists in `assets/worlds/` —
/// everything shown about it (name, tone, whether it's curated) is always
/// read live from the world itself via [GameController.loadWorldInfo],
/// never duplicated in this list.
const _availableWorldSlugs = [
  'curated_zombie_01_ultimo_tren',
  'xianxia_lianshu',
  'xianxia',
];

/// Friendly display name for a world's `theme` slug, shown as the card's
/// overline instead of the raw JSON value (e.g. `postapoc_zombie`). Purely
/// presentational — the underlying slug still drives identity/lookup, this
/// map only exists because the menu has to read well to a first-time player.
const _themeLabels = {
  'postapoc_zombie': 'Postapocalíptica · supervivencia tras el colapso',
  'xianxia': 'Xianxia · cultivo y ascensión inmortal',
};

/// The three story types the menu groups campaigns into (GDD §1: freeform,
/// curated, hybrid — reframed here in player-facing language). Determined
/// from the world's own declared shape, never hardcoded per-slug.
enum _StoryModule { complete, preArmada, aiNarrator }

extension on _StoryModule {
  String get title => switch (this) {
        _StoryModule.complete => 'Historias completas',
        _StoryModule.preArmada => 'Historias pre-armadas',
        _StoryModule.aiNarrator => 'Historias con narrador por IA',
      };

  String get description => switch (this) {
        _StoryModule.complete =>
          'Una historia ya armada de punta a punta. Tus decisiones eligen el camino, pero cada escena está escrita a mano.',
        _StoryModule.preArmada =>
          'Una campaña pre-diseñada, con hitos fijos, que un narrador de IA viste turno a turno según tus elecciones.',
        _StoryModule.aiNarrator =>
          'Toda la historia se genera en tiempo real, sin guion previo. Próximamente.',
      };

  /// Only the freeform, fully-generated mode is gated off for now — the
  /// other two are real, playable content.
  bool get enabled => this != _StoryModule.aiNarrator;
}

_StoryModule _moduleFor(World world) {
  if (world.storyGraph == null) return _StoryModule.aiNarrator;
  return world.aiRuntimeRequired ? _StoryModule.preArmada : _StoryModule.complete;
}

/// Lets the player pick which world to enter (CLAUDE.md §1: freeform,
/// curated or hybrid modes over the same engine). Reached from
/// [SplashScreen]'s "Comenzar", and from the back arrow inside a story
/// ([StatusBar.onBack]) — the same [GameController] instance is reused
/// either way, so picking the story already in progress just resumes it.
class WorldSelectScreen extends StatefulWidget {
  const WorldSelectScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<WorldSelectScreen> createState() => _WorldSelectScreenState();
}

class _WorldSelectScreenState extends State<WorldSelectScreen> {
  late final Future<List<World>> _worlds = Future.wait(
    _availableWorldSlugs.map(widget.controller.loadWorldInfo),
  );

  void _select(World world) {
    if (!_moduleFor(world).enabled) return;
    final controller = widget.controller;
    // Already the active session in memory (e.g. the player used the back
    // arrow mid-story) — resume it instead of restarting chargen.
    if (controller.isReady && controller.world?.slug == world.slug) {
      _goToGame(world.slug);
      return;
    }
    if (world.origins.isNotEmpty) {
      _goToChargen(world);
    } else {
      _goToGame(world.slug);
    }
  }

  void _goToChargen(World world, {bool forceNew = false}) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => ChargenScreen(
          controller: widget.controller,
          worldSlug: world.slug,
          world: world,
          forceNew: forceNew,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  /// "Reiniciar historia" — abandons whatever session already exists for
  /// [world] (in memory or persisted in Supabase) and starts a clean one, for
  /// a player who wants to play a curated campaign again from the top
  /// instead of always resuming where they left off.
  Future<void> _restart(World world) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AetherColors.surface,
        title: Text(world.name, style: AetherType.title),
        content: Text(
          'Vas a reiniciar esta historia desde el principio. El progreso actual se pierde. ¿Confirmás?',
          style: AetherType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (world.origins.isNotEmpty) {
      _goToChargen(world, forceNew: true);
    } else {
      await widget.controller.start(world.slug, forceNew: true);
      if (!mounted) return;
      _goToGame(world.slug);
    }
  }

  void _goToGame(String worldSlug) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) =>
            GameScreen(controller: widget.controller, worldSlug: worldSlug),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Elegí tu historia', style: AetherType.display),
                    const SizedBox(height: AetherSpace.xs),
                    Text('Cada mundo se escribe distinto.',
                        style: AetherType.body
                            .copyWith(color: AetherColors.parchmentDim, fontSize: 15)),
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
                          final byModule = <_StoryModule, List<World>>{
                            for (final m in _StoryModule.values) m: [],
                          };
                          for (final world in worlds) {
                            byModule[_moduleFor(world)]!.add(world);
                          }
                          return ListView(
                            children: [
                              for (final module in _StoryModule.values)
                                if (byModule[module]!.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: AetherSpace.xl),
                                    child: _StoryModuleSection(
                                      module: module,
                                      worlds: byModule[module]!,
                                      onTap: _select,
                                      onRestart: _restart,
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

/// A module's header (title + one-line explanation) followed by its cards.
/// When the module is disabled (only the AI-narrator one, for now), cards
/// render dimmed and don't respond to taps — present, but clearly "not yet".
class _StoryModuleSection extends StatelessWidget {
  const _StoryModuleSection({
    required this.module,
    required this.worlds,
    required this.onTap,
    required this.onRestart,
  });

  final _StoryModule module;
  final List<World> worlds;
  final ValueChanged<World> onTap;
  final ValueChanged<World> onRestart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: AetherColors.goldGlow,
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            module.title,
            style: AetherType.title.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 2),
          Text(module.description, style: AetherType.caption),
          const SizedBox(height: AetherSpace.lg),
          for (final world in worlds)
            Padding(
              padding: const EdgeInsets.only(bottom: AetherSpace.md),
              child: _StoryCard(
                world: world,
                enabled: module.enabled,
                onTap: () => onTap(world),
                onRestart: module.enabled ? () => onRestart(world) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.world,
    required this.onTap,
    this.enabled = true,
    this.onRestart,
  });

  final World world;
  final VoidCallback onTap;
  final bool enabled;

  /// `null` hides the restart affordance entirely (disabled module). When
  /// present, always usable — the player may already have a session resting
  /// server-side even on a fresh app load, where there's no client-side way
  /// to know that in advance without the tap itself.
  final VoidCallback? onRestart;

  String get _themeLabel => _themeLabels[world.theme] ?? world.theme.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(AetherSpace.lg),
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: AetherRadius.allMd,
            border: Border.all(color: AetherColors.hairlineStrong),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_themeLabel.toUpperCase(),
                        style: AetherType.overline
                            .copyWith(color: AetherColors.gold)),
                    const SizedBox(height: 4),
                    Text(world.name, style: AetherType.title),
                    const SizedBox(height: 6),
                    Text(world.tone, style: AetherType.caption),
                    if (world.catalogDescription != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      world.catalogDescription!,
                      style: AetherType.body.copyWith(
                          color: AetherColors.parchmentDim, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (world.estimatedDurationMinutes != null ||
                      world.contentWarning != null) ...[
                    const SizedBox(height: 6),
                    if (world.estimatedDurationMinutes != null)
                      Text(
                        '~${(world.estimatedDurationMinutes! / 60).round()} h de juego',
                        style: AetherType.caption
                            .copyWith(color: AetherColors.goldSoft),
                      ),
                    if (world.contentWarning != null)
                      Text(
                        world.contentWarning!,
                        style: AetherType.caption
                            .copyWith(color: AetherColors.parchmentDim),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AetherSpace.sm),
            if (onRestart != null)
              IconButton(
                onPressed: onRestart,
                tooltip: 'Reiniciar historia',
                icon: const Icon(Icons.replay_rounded, size: 20),
                color: AetherColors.parchmentFaint,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            Icon(
              enabled ? Icons.chevron_right : Icons.lock_outline_rounded,
              color: AetherColors.goldSoft,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
