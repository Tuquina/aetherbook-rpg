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
const _availableWorldSlugs = ['xianxia_lianshu', 'xianxia'];

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

  void _goToChargen(World world) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AetherMotion.slow,
        pageBuilder: (_, _, _) => ChargenScreen(
          controller: widget.controller,
          worldSlug: world.slug,
          world: world,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
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
                          return ListView.separated(
                            itemCount: worlds.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AetherSpace.md),
                            itemBuilder: (context, i) => _StoryCard(
                              world: worlds[i],
                              onTap: () => _select(worlds[i]),
                            ),
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

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.world, required this.onTap});

  final World world;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final curated = world.storyGraph != null;
    return GestureDetector(
      onTap: onTap,
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
                  Text(world.theme.toUpperCase(),
                      style: AetherType.overline
                          .copyWith(color: AetherColors.gold)),
                  const SizedBox(height: 4),
                  Text(world.name, style: AetherType.title),
                  const SizedBox(height: 6),
                  Text(
                    curated ? 'Campaña curada · ${world.tone}' : 'Modo libre · ${world.tone}',
                    style: AetherType.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AetherSpace.sm),
            const Icon(Icons.chevron_right, color: AetherColors.goldSoft),
          ],
        ),
      ),
    );
  }
}
