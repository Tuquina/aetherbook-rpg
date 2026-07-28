import 'package:flutter/material.dart';

import '../core/state/character.dart';
import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'design/world_theme.dart';
import 'widgets/sheet_shell.dart';

/// The character's full stats — attributes, resources, origin, personal item
/// and vow — as a bottom sheet reachable by tapping the name in `StatusBar`
/// (V2 design prototype §1a's "Toca el nombre para la ficha"). Consolidates
/// what used to be `StatusBar`'s always-visible resource pills (V2 Stage 5):
/// the header keeps identity + EXP progress at a glance; everything else
/// lives here, one tap away, instead of competing with the reading column
/// for space on every turn.
Future<void> showCharacterSheet(
  BuildContext context, {
  required World world,
  required Character character,
}) {
  final theme = WorldTheme.forWorld(world);
  final title =
      theme.titleUppercase ? character.name.toUpperCase() : character.name;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AetherColors.void_.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (_) => SheetShell(
      title: title,
      titleStyle: theme.titleStyle(AetherType.title),
      child: _CharacterSheetBody(world: world, character: character),
    ),
  );
}

class _CharacterSheetBody extends StatelessWidget {
  const _CharacterSheetBody({required this.world, required this.character});

  final World world;
  final Character character;

  @override
  Widget build(BuildContext context) {
    final origin = world.originByIdOrNull(character.originId);
    final vow = world.vowByIdOrNull(character.vowId);
    final personalItem = character.personalItem ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.xl, AetherSpace.md, AetherSpace.xl, AetherSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (origin != null || personalItem.isNotEmpty) ...[
            Wrap(
              spacing: AetherSpace.sm,
              runSpacing: AetherSpace.sm,
              children: [
                if (origin != null)
                  _InfoChip(icon: Icons.person_outline_rounded, label: origin.displayName),
                if (personalItem.isNotEmpty)
                  _InfoChip(icon: Icons.auto_stories_rounded, label: personalItem),
              ],
            ),
            const SizedBox(height: AetherSpace.lg),
          ],
          if (vow != null) ...[
            Container(
              padding: const EdgeInsets.all(AetherSpace.lg),
              decoration: BoxDecoration(
                color: AetherColors.goldGlow,
                borderRadius: AetherRadius.allLg,
                border: Border.all(color: AetherColors.gold.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(world.chargenVowLabel.toUpperCase(),
                      style: AetherType.overline.copyWith(color: AetherColors.goldSoft)),
                  const SizedBox(height: AetherSpace.sm),
                  Text('"${vow.text}"',
                      style: AetherType.body.copyWith(
                          fontStyle: FontStyle.italic, color: AetherColors.parchment)),
                ],
              ),
            ),
            const SizedBox(height: AetherSpace.xl),
          ],
          if (world.attributeKeys.isNotEmpty) ...[
            Text('Atributos', style: AetherType.overline),
            const SizedBox(height: AetherSpace.sm),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AetherSpace.sm,
              crossAxisSpacing: AetherSpace.sm,
              childAspectRatio: 2.4,
              children: [
                for (final key in world.attributeKeys)
                  _AttributeCard(label: key, value: character.attributes[key] ?? 1),
              ],
            ),
            const SizedBox(height: AetherSpace.xl),
          ],
          if (character.resources.isNotEmpty) ...[
            Text('Recursos', style: AetherType.overline),
            const SizedBox(height: AetherSpace.sm),
            Wrap(
              spacing: AetherSpace.sm,
              runSpacing: AetherSpace.sm,
              children: [
                for (final entry in character.resources.entries)
                  _ResourcePill(name: entry.key, value: entry.value),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allPill,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AetherColors.goldSoft),
          const SizedBox(width: 6),
          Text(label,
              style: AetherType.caption.copyWith(color: AetherColors.parchment)),
        ],
      ),
    );
  }
}

class _AttributeCard extends StatelessWidget {
  const _AttributeCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm),
      decoration: BoxDecoration(
        color: AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allMd,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AetherType.overline.copyWith(
                  color: AetherColors.parchmentDim, fontSize: 10)),
          Text('$value',
              style: const TextStyle(
                  color: AetherColors.parchment,
                  fontWeight: FontWeight.w700,
                  fontSize: 18)),
        ],
      ),
    );
  }
}

/// Same treatment `StatusBar` used to show inline, relocated here (Stage 5).
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
