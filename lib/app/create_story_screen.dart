import 'package:flutter/material.dart';

import '../core/state/game_session.dart';
import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'game_controller.dart';
import 'story_module_screen.dart' show Pressable, StoryCard;
import 'widgets/atmosphere.dart';
import 'world_select_screen.dart'
    show StoryModule, StoryModuleStyle, storyModuleStyle;

/// The freeform "crea tu propia historia" module's own screen — replaces
/// [StoryModuleScreen] for `StoryModule.aiNarrator` specifically (the other
/// two modules keep using it unchanged). Unlike a curated/hybrid module,
/// where each world *is* one campaign with at most one active session, a
/// freeform genre can have several stories going at once (CLAUDE.md Fase 2:
/// the template — the genre — is shared, but each created story belongs to
/// the player). So this screen shows two sections instead of one list:
/// the player's own saved stories (if any), and the 5 genres to start a new
/// one from.
class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({
    super.key,
    required this.controller,
    required this.worlds,
    required this.onSelectGenre,
    required this.onResumeStory,
    required this.onAbandonStory,
  });

  final GameController controller;

  /// The 5 genre worlds (aiNarrator module's `_moduleFor` bucket).
  final List<World> worlds;

  /// Starts a brand-new story in this genre (always chargen, never resumes).
  final ValueChanged<World> onSelectGenre;

  /// Resumes one exact saved story.
  final ValueChanged<GameSessionSummary> onResumeStory;

  /// Confirms and abandons one saved story — the caller owns the
  /// confirmation dialog (same pattern as `WorldSelectScreen._restart`); this
  /// screen just awaits it and reloads its own list once it resolves.
  final Future<void> Function(GameSessionSummary) onAbandonStory;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  late Future<List<GameSessionSummary>> _stories = _load();

  /// Genre display name (`World.name`, e.g. "Cyberpunk") per world slug —
  /// resolved from `widget.worlds` rather than re-deriving it from a saved
  /// story's `theme`, which isn't guaranteed to equal its `worldSlug` in
  /// general (`_themeLabels` in story_module_screen.dart is keyed by theme
  /// for exactly that reason).
  late final Map<String, String> _genreNameBySlug = {
    for (final w in widget.worlds) w.slug: w.name,
  };

  Future<List<GameSessionSummary>> _load() =>
      widget.controller.listCreatedStories([for (final w in widget.worlds) w.slug]);

  void _reload() => setState(() {
        _stories = _load();
      });

  Future<void> _abandon(GameSessionSummary summary) async {
    await widget.onAbandonStory(summary);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final style = storyModuleStyle(StoryModule.aiNarrator);
    return Scaffold(
      body: AetherBackground(
        accent: style.accent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AetherSpace.xl, 0, AetherSpace.xl, AetherSpace.huge),
                      children: [
                        _ModuleBanner(style: style),
                        const SizedBox(height: AetherSpace.xl),
                        FutureBuilder<List<GameSessionSummary>>(
                          future: _stories,
                          builder: (context, snapshot) {
                            final stories = snapshot.data;
                            if (stories == null || stories.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tus historias', style: AetherType.overline),
                                const SizedBox(height: AetherSpace.sm),
                                for (final story in stories)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: AetherSpace.md),
                                    child: _SavedStoryCard(
                                      story: story,
                                      genreName: _genreNameBySlug[story.worldSlug] ??
                                          story.worldSlug,
                                      accent: style.accent,
                                      onTap: () => widget.onResumeStory(story),
                                      onAbandon: () => _abandon(story),
                                    ),
                                  ),
                                const SizedBox(height: AetherSpace.md),
                              ],
                            );
                          },
                        ),
                        Text('Empezar una historia nueva', style: AetherType.overline),
                        const SizedBox(height: AetherSpace.sm),
                        for (final world in widget.worlds)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AetherSpace.md),
                            child: StoryCard(
                              world: world,
                              accent: style.accent,
                              onTap: () => widget.onSelectGenre(world),
                            ),
                          ),
                      ],
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

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AetherSpace.sm, AetherSpace.lg, AetherSpace.xl, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AetherColors.goldSoft),
            ),
            const SizedBox(width: AetherSpace.xs),
            Text('Tipos de historia',
                style: AetherType.overline
                    .copyWith(color: AetherColors.parchmentFaint)),
          ],
        ),
      );
}

class _ModuleBanner extends StatelessWidget {
  const _ModuleBanner({required this.style});

  final StoryModuleStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AetherSpace.xl),
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.glow, Colors.transparent],
        ),
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: style.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: style.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: style.accent.withValues(alpha: 0.5)),
            ),
            child: Icon(style.icon, color: style.bright, size: 22),
          ),
          const SizedBox(width: AetherSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Crea tu propia historia', style: AetherType.title),
                const SizedBox(height: 4),
                Text(
                  'Eliges un género, armas tu personaje y la IA narra lo que '
                  'sigue turno a turno, sin guion previo. Puedes tener varias '
                  'historias a la vez.',
                  style: AetherType.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One saved story: character name, genre label, and how long ago it was
/// last played. Tapping resumes it; the trash icon abandons it (with the
/// confirmation the caller's [CreateStoryScreen.onAbandonStory] provides).
class _SavedStoryCard extends StatelessWidget {
  const _SavedStoryCard({
    required this.story,
    required this.genreName,
    required this.accent,
    required this.onTap,
    required this.onAbandon,
  });

  final GameSessionSummary story;
  final String genreName;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onAbandon;

  String get _lastPlayed {
    final since = DateTime.now().difference(story.updatedAt);
    if (since.inMinutes < 1) return 'ahora mismo';
    if (since.inHours < 1) return 'hace ${since.inMinutes} min';
    if (since.inDays < 1) return 'hace ${since.inHours} h';
    return 'hace ${since.inDays} d';
  }

  /// The story's own title if the player set one at chargen, or the genre
  /// name as a fallback for a story created before titles existed.
  String get _displayTitle {
    final title = story.title;
    return title != null && title.trim().isNotEmpty ? title.trim() : genreName;
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: (pressed) => AnimatedContainer(
        duration: AetherMotion.fast,
        padding: const EdgeInsets.all(AetherSpace.lg),
        decoration: BoxDecoration(
          color: pressed ? AetherColors.surfaceRaised : AetherColors.surface,
          borderRadius: AetherRadius.allMd,
          border: Border.all(
            color: pressed
                ? accent.withValues(alpha: 0.6)
                : AetherColors.hairlineStrong,
          ),
          boxShadow: pressed ? AetherShadow.glow(accent, strength: 0.18) : null,
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AetherRadius.allPill,
              ),
            ),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(genreName.toUpperCase(),
                      style: AetherType.overline.copyWith(color: accent)),
                  const SizedBox(height: 4),
                  Text(_displayTitle, style: AetherType.title),
                  const SizedBox(height: 4),
                  Text(story.characterName, style: AetherType.body),
                  const SizedBox(height: 4),
                  Text(_lastPlayed, style: AetherType.caption),
                ],
              ),
            ),
            IconButton(
              onPressed: onAbandon,
              tooltip: 'Abandonar historia',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: AetherColors.parchmentFaint,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Icon(Icons.chevron_right, color: accent),
          ],
        ),
      ),
    );
  }
}
