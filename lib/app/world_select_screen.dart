import 'package:flutter/material.dart';

import '../core/world/world.dart';
import 'chargen_screen.dart';
import 'codex_screen.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'game_screen.dart';
import 'story_module_screen.dart';
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
        StoryModule.aiNarrator => 'Historias con narrador por IA',
      };

  String get description => switch (this) {
        StoryModule.complete =>
          'Una historia ya armada de punta a punta. Tus decisiones eligen el camino, pero cada escena está escrita a mano.',
        StoryModule.preArmada =>
          'Una campaña pre-diseñada, con hitos fijos, que un narrador de IA viste turno a turno según tus elecciones.',
        StoryModule.aiNarrator =>
          'Toda la historia se genera en tiempo real, sin guion previo. Próximamente.',
      };

  /// The one-line teaser shown on the picker card — a shorter cousin of
  /// [description], which is reserved for the module's own screen.
  String get teaser => switch (this) {
        StoryModule.complete => 'Escrita a mano, de punta a punta.',
        StoryModule.preArmada => 'Rieles fijos, vestidos por IA en vivo.',
        StoryModule.aiNarrator => 'Generada en tiempo real. Próximamente.',
      };

  /// Only the freeform, fully-generated mode is gated off for now — the
  /// other two are real, playable content.
  bool get enabled => this != StoryModule.aiNarrator;
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
          accent: AetherColors.parchmentFaint,
          bright: AetherColors.parchmentDim,
          glow: Color(0x117E7565),
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

  void _openModule(StoryModule module, List<World> worlds) {
    if (!module.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AetherColors.surfaceRaised,
          content: Text('El narrador 100% por IA todavía no tiene mundos cargados.',
              style: TextStyle(color: AetherColors.parchment)),
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
                    const SizedBox(height: AetherSpace.lg),
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
