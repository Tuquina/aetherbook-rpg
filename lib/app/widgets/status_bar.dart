import 'package:flutter/material.dart';

import '../../core/engine/exp_progression.dart';
import '../../core/state/character.dart';
import '../../core/world/world.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The persistent status bar (GDD §9: "ficha/diario siempre a mano"). Shows
/// who you are, your progression toward the next realm, your resources, and a
/// door into the Codex. This is the visible face of the authoritative state
/// (CLAUDE.md §2.1) — what the story bends around.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.world,
    required this.character,
    required this.onOpenCodex,
  });

  final World world;
  final Character character;
  final VoidCallback onOpenCodex;

  static const _expProgression = ExpProgression();

  @override
  Widget build(BuildContext context) {
    final toNext = _expProgression.expToNext(character.level);
    final progress = (character.exp / toNext).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.lg, AetherSpace.md, AetherSpace.sm, AetherSpace.md),
      decoration: const BoxDecoration(
        color: AetherColors.surface,
        border: Border(bottom: BorderSide(color: AetherColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(world.name.toUpperCase(),
                        style: AetherType.overline
                            .copyWith(color: AetherColors.gold)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(character.name,
                              style: AetherType.title.copyWith(fontSize: 17),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: AetherSpace.sm),
                        _levelPill(character.level),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenCodex,
                tooltip: 'Cómo se juega',
                icon: const Icon(Icons.menu_book_rounded,
                    color: AetherColors.goldSoft, size: 22),
              ),
            ],
          ),
          const SizedBox(height: AetherSpace.sm),
          _expBar(progress, character.exp, toNext),
          const SizedBox(height: AetherSpace.md),
          Wrap(
            spacing: AetherSpace.sm,
            runSpacing: AetherSpace.sm,
            children: [
              for (final entry in character.resources.entries)
                _ResourcePill(name: entry.key, value: entry.value),
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelPill(int level) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AetherColors.goldGlow,
          borderRadius: AetherRadius.allPill,
          border: Border.all(color: AetherColors.gold.withValues(alpha: 0.4)),
        ),
        child: Text('Reino $level',
            style: AetherType.overline.copyWith(
                color: AetherColors.goldSoft, fontSize: 10, letterSpacing: 0.8)),
      );

  Widget _expBar(double progress, int exp, int toNext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AetherRadius.allPill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: AetherMotion.slow,
              curve: AetherMotion.standard,
              builder: (context, value, _) => Stack(
                children: [
                  Container(height: 5, color: AetherColors.void_),
                  FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      height: 5,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AetherColors.gold,
                          AetherColors.goldBright,
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text('$exp / $toNext EXP hacia el próximo reino',
              style: AetherType.caption
                  .copyWith(fontSize: 10.5, color: AetherColors.parchmentFaint)),
        ],
      );
}

class _ResourcePill extends StatelessWidget {
  const _ResourcePill({required this.name, required this.value});

  final String name;
  final int value;

  IconData get _icon => switch (name.toLowerCase()) {
        'qi' => Icons.blur_on,
        'salud' || 'vida' => Icons.favorite_rounded,
        'maná' || 'mana' => Icons.water_drop_rounded,
        'energía' || 'energia' => Icons.bolt_rounded,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AetherSpace.md, vertical: AetherSpace.xs + 2),
      decoration: BoxDecoration(
        color: AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allPill,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 14, color: AetherColors.goldSoft),
          const SizedBox(width: 6),
          Text(name,
              style: AetherType.caption
                  .copyWith(color: AetherColors.parchmentDim, fontSize: 12)),
          const SizedBox(width: 5),
          Text('$value',
              style: const TextStyle(
                  color: AetherColors.parchment,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
  }
}
