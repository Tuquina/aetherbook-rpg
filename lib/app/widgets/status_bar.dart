import 'package:flutter/material.dart';

import '../../core/engine/exp_progression.dart';
import '../../core/state/character.dart';
import '../../core/world/world.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The persistent status bar (GDD §9: "ficha/diario siempre a mano"). Shows
/// who you are, your progression toward the next realm, and doors into your
/// full character sheet, inventory and the Codex. This is the visible face
/// of the authoritative state (CLAUDE.md §2.1) — what the story bends around.
///
/// Resources/attributes/vow/origin used to render inline here as a `Wrap` of
/// pills; V2 Stage 5 moved all of that into `CharacterSheetSheet`, one tap
/// away via [onOpenCharacterSheet] on the name (V2 design prototype §1a:
/// "Toca el nombre para la ficha") — this header now only carries identity
/// and EXP progress, so it never competes with the reading column for space.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.world,
    required this.character,
    required this.onOpenCodex,
    required this.onOpenInventory,
    required this.onOpenCharacterSheet,
    this.onBack,
    this.collapse = 0.0,
  });

  final World world;
  final Character character;
  final VoidCallback onOpenCodex;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenCharacterSheet;

  /// Opens the story menu (V2 Stage 5) rather than leaving the story
  /// directly — keeps this session in memory either way (picking the same
  /// story again resumes it). `null` hides the back affordance.
  final VoidCallback? onBack;

  /// 0 (fully expanded, the default) to 1 (fully collapsed) — driven directly
  /// by the reading scroll offset in [GameScreen] (V2 design prototype §1a:
  /// "cabecera de dos estados, ceremonial → 52px al hacer scroll"), never by
  /// its own timer. At 1, the EXP bar folds away and a thin EXP rail takes
  /// its place along the bottom edge, so the identity row (back/name/level/
  /// inventory/codex) stays put while reading reclaims the vertical space
  /// the meta row used.
  final double collapse;

  @override
  Widget build(BuildContext context) {
    final prog = world.progression;
    final expProgression =
        ExpProgression(baseExpPerLevel: prog.baseExpPerLevel);
    final toNext = expProgression.expToNext(character.level);
    final progress = (character.exp / toNext).clamp(0.0, 1.0);
    final expanded = 1.0 - collapse.clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        color: AetherColors.surface,
        border: Border(bottom: BorderSide(color: AetherColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AetherSpace.lg, AetherSpace.lg, AetherSpace.sm, AetherSpace.sm),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    tooltip: 'Menú de la historia',
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: AetherColors.goldSoft, size: 22),
                  ),
                Expanded(
                  child: InkWell(
                    onTap: onOpenCharacterSheet,
                    borderRadius: AetherRadius.allSm,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
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
                              if (prog.enabled) ...[
                                const SizedBox(width: AetherSpace.sm),
                                _levelPill(
                                    prog.unitLabelCapitalized, character.level),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onOpenInventory,
                  tooltip: 'Inventario',
                  icon: Badge(
                    isLabelVisible: character.list('inventory').isNotEmpty,
                    label: Text('${character.list('inventory').length}'),
                    backgroundColor: AetherColors.gold,
                    textColor: AetherColors.void_,
                    child: const Icon(Icons.inventory_2_rounded,
                        color: AetherColors.goldSoft, size: 22),
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
          ),
          if (prog.enabled)
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: expanded,
                child: Opacity(
                  opacity: expanded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AetherSpace.lg, 0, AetherSpace.lg, AetherSpace.md),
                    child: _expBar(progress, character.exp, toNext, prog.unitLabel),
                  ),
                ),
              ),
            ),
          if (prog.enabled)
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: collapse.clamp(0.0, 1.0),
                child: Opacity(
                  opacity: collapse.clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AetherSpace.lg, 0, AetherSpace.lg, AetherSpace.sm),
                    child: ClipRRect(
                      borderRadius: AetherRadius.allPill,
                      child: Container(
                        height: 2,
                        color: AetherColors.void_,
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(color: AetherColors.gold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _levelPill(String label, int level) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 2),
        decoration: BoxDecoration(
          color: AetherColors.goldGlow,
          borderRadius: AetherRadius.allPill,
          border: Border.all(color: AetherColors.gold.withValues(alpha: 0.4)),
        ),
        child: Text('$label $level',
            style: AetherType.overline.copyWith(
                color: AetherColors.goldSoft, fontSize: 10, letterSpacing: 0.8)),
      );

  Widget _expBar(double progress, int exp, int toNext, String unit) => Column(
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
          Text('$exp / $toNext EXP hacia el próximo $unit',
              style: AetherType.caption
                  .copyWith(fontSize: 10.5, color: AetherColors.parchmentFaint)),
        ],
      );
}
