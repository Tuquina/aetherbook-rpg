import 'package:flutter/material.dart';

import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'story_module_screen.dart' show StoryCard;
import 'story_navigation.dart';
import 'widgets/atmosphere.dart';

/// "Explorar" (Admin Stage 4): every published community novel — a campaign
/// authored via "Escribir" with no `officialModule` set, so it never lands
/// in the real "Historias completas"/"Historias pre-armadas" catalog (Admin
/// Stage 3's official campaigns do that instead). Reuses [StoryCard] as-is:
/// once `CompositeWorldRepository` resolves a summary's slug into a real
/// [World] (Admin Stage 3/4), a community novel opens exactly like any
/// bundled one — same chargen-or-straight-to-game decision, same
/// [StoryNavigation.open].
class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key, required this.controller});

  final GameController controller;

  static Route<void> route({required GameController controller}) =>
      MaterialPageRoute(builder: (_) => ExplorarScreen(controller: controller));

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  late final Future<List<World>> _worlds = _load();

  Future<List<World>> _load() async {
    final campaignDrafts = widget.controller.campaignDrafts;
    if (campaignDrafts == null) return const [];
    final summaries = await campaignDrafts.listExplorable();
    return Future.wait(summaries.map((s) => widget.controller.loadWorldInfo(s.slug)));
  }

  Future<void> _open(World world) => StoryNavigation.open(context, widget.controller, world);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AetherSpace.sm, AetherSpace.lg, AetherSpace.xl, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: AetherColors.goldSoft),
                        ),
                        const SizedBox(width: AetherSpace.xs),
                        Text('Explorar',
                            style:
                                AetherType.overline.copyWith(color: AetherColors.parchmentFaint)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<World>>(
                      future: _worlds,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator(color: AetherColors.gold));
                        }
                        final worlds = snapshot.data!;
                        if (worlds.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AetherSpace.xl),
                              child: Text(
                                'Todavía no hay novelas publicadas por la comunidad.',
                                style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                              AetherSpace.xl, AetherSpace.lg, AetherSpace.xl, AetherSpace.huge),
                          children: [
                            Text(
                              'Historias escritas por otros jugadores, publicadas desde "Escribir".',
                              style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
                            ),
                            const SizedBox(height: AetherSpace.xl),
                            for (final world in worlds)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AetherSpace.md),
                                child: StoryCard(
                                  world: world,
                                  accent: AetherColors.gold,
                                  icon: Icons.groups_rounded,
                                  onTap: () => _open(world),
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
    );
  }
}
