import 'package:flutter/material.dart';

import '../core/state/character.dart';
import '../core/world/item_definition.dart';
import '../core/world/world.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'widgets/atmosphere.dart';

/// Shows what's in `character.lists['inventory']` — bare ids until now,
/// this is the first place a player actually sees a name and a description
/// for what they're carrying (CLAUDE.md §11 Fase 1: "inventario real").
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key, required this.world, required this.character});

  final World world;
  final Character character;

  static Route<void> route({required World world, required Character character}) =>
      MaterialPageRoute(
        builder: (_) => InventoryScreen(world: world, character: character),
      );

  @override
  Widget build(BuildContext context) {
    final itemIds = character.list('inventory');
    return Scaffold(
      body: AetherBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  _header(context),
                  Expanded(
                    child: itemIds.isEmpty
                        ? const _EmptyState()
                        : _InventoryList(world: world, itemIds: itemIds),
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
            AetherSpace.sm, AetherSpace.sm, AetherSpace.lg, AetherSpace.sm),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AetherColors.goldSoft),
            ),
            const SizedBox(width: AetherSpace.xs),
            Text('Inventario', style: AetherType.display.copyWith(fontSize: 22)),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AetherSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 40, color: AetherColors.parchmentFaint),
            const SizedBox(height: AetherSpace.md),
            Text(
              'Todavía no tenés nada.',
              style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.lg, AetherSpace.sm, AetherSpace.lg, AetherSpace.huge),
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
        color: AetherColors.surface,
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
