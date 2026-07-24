import 'package:flutter/material.dart';

import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/atmosphere.dart';
import 'world_select_screen.dart'
    show StoryModule, StoryModuleInfo, StoryModuleStyle, storyModuleStyle;

/// Reached by tapping one of the three module cards on [WorldSelectScreen]:
/// shows that module's title + explanation up top, then the campaigns that
/// belong to it. Selecting or restarting a campaign is delegated back to the
/// caller so the whole app keeps its single [GameController] flow.
class StoryModuleScreen extends StatelessWidget {
  const StoryModuleScreen({
    super.key,
    required this.module,
    required this.worlds,
    required this.onTap,
    required this.onRestart,
  });

  final StoryModule module;
  final List<World> worlds;
  final ValueChanged<World> onTap;
  final ValueChanged<World> onRestart;

  @override
  Widget build(BuildContext context) {
    final style = storyModuleStyle(module);
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
                      padding: const EdgeInsets.fromLTRB(AetherSpace.xl, 0,
                          AetherSpace.xl, AetherSpace.huge),
                      children: [
                        _ModuleBanner(module: module, style: style),
                        const SizedBox(height: AetherSpace.xl),
                        for (final world in worlds)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AetherSpace.md),
                            child: _StoryCard(
                              world: world,
                              accent: style.accent,
                              onTap: () => onTap(world),
                              onRestart: () => onRestart(world),
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
                style:
                    AetherType.overline.copyWith(color: AetherColors.parchmentFaint)),
          ],
        ),
      );
}

/// The module's identity, restated at the top of its own screen: icon,
/// title, and the full explanation (the card on the picker screen only had
/// room for a one-liner).
class _ModuleBanner extends StatelessWidget {
  const _ModuleBanner({required this.module, required this.style});

  final StoryModule module;
  final StoryModuleStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(module.title, style: AetherType.title),
                const SizedBox(height: 4),
                Text(module.description, style: AetherType.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single campaign's card: name, tone, catalog blurb, duration/warning,
/// and the tap target that leads into it. Carries the parent module's
/// accent so every card on a given screen reads as one family.
class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.world,
    required this.accent,
    required this.onTap,
    required this.onRestart,
  });

  final World world;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRestart;

  static const _themeLabels = {
    'postapoc_zombie': 'Postapocalíptica · supervivencia tras el colapso',
    'xianxia': 'Xianxia · cultivo y ascensión inmortal',
  };

  String get _themeLabel => _themeLabels[world.theme] ?? world.theme.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return _Pressable(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 3,
              height: 46,
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
                  Text(_themeLabel.toUpperCase(),
                      style: AetherType.overline.copyWith(color: accent)),
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
            IconButton(
              onPressed: onRestart,
              tooltip: 'Reiniciar historia',
              icon: const Icon(Icons.replay_rounded, size: 20),
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

/// Shared press-scale wrapper: every tappable card in the story-select flow
/// dips slightly and hands its pressed state to [child] so the accent border
/// can brighten with it — one tactile feel across module and story cards.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget Function(bool pressed) child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
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
        scale: _pressed ? 0.98 : 1,
        duration: AetherMotion.fast,
        curve: AetherMotion.standard,
        child: widget.child(_pressed),
      ),
    );
  }
}
