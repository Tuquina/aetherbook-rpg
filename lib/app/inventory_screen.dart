import 'package:flutter/material.dart';

import '../core/state/character.dart';
import '../core/world/item_definition.dart';
import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/sheet_shell.dart';

/// Shows what's in `character.lists['inventory']` — bare ids until now,
/// this is the first place a player actually sees a name and a description
/// for what they're carrying (CLAUDE.md §11 Fase 1: "inventario real").
///
/// A bottom sheet (V2 Stage 5), not a pushed screen — reachable without
/// losing your place in the reading column underneath.
Future<void> showInventorySheet(
  BuildContext context, {
  required World world,
  required Character character,
}) {
  final itemIds = character.list('inventory');
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AetherColors.void_.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (_) => SheetShell(
      title: 'Inventario',
      child: itemIds.isEmpty
          ? const _EmptyState()
          : _InventoryList(world: world, itemIds: itemIds),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.xl, AetherSpace.lg, AetherSpace.xl, AetherSpace.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              size: 40, color: AetherColors.parchmentFaint),
          const SizedBox(height: AetherSpace.md),
          Text(
            'Todavía no tienes nada.',
            style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.world, required this.itemIds});

  final World world;
  final List<String> itemIds;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.xl, AetherSpace.md, AetherSpace.xl, AetherSpace.xl),
      itemCount: itemIds.length,
      separatorBuilder: (_, _) => const SizedBox(height: AetherSpace.md),
      itemBuilder: (context, i) => _ItemCard(
        id: itemIds[i],
        definition: world.findItem(itemIds[i]),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.id, required this.definition});

  final String id;

  /// `null` when the world hasn't described this item id yet — the card
  /// still renders, just with the raw id standing in for a name.
  final ItemDefinition? definition;

  IconData get _icon => switch (definition?.category) {
        ItemCategory.key => Icons.vpn_key_rounded,
        ItemCategory.tool => Icons.build_rounded,
        ItemCategory.weapon => Icons.gpp_maybe_rounded,
        ItemCategory.medicine => Icons.medical_services_rounded,
        ItemCategory.document => Icons.description_rounded,
        ItemCategory.misc || null => Icons.inventory_2_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final name = definition?.displayName ?? id;
    final description = definition?.description ?? '';
    return Container(
      padding: const EdgeInsets.all(AetherSpace.lg),
      decoration: BoxDecoration(
        color: AetherColors.surfaceRaised,
        borderRadius: AetherRadius.allLg,
        border: Border.all(color: AetherColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AetherSpace.sm),
            decoration: BoxDecoration(
              color: AetherColors.goldGlow,
              borderRadius: AetherRadius.allMd,
            ),
            child: Icon(_icon, size: 18, color: AetherColors.gold),
          ),
          const SizedBox(width: AetherSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AetherType.label),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description, style: AetherType.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
