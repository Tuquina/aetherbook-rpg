import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'brand_mark.dart';

/// The destinations the home dashboard's nav chrome offers (V2 design
/// prototype §8a/§8b) — "Ajustes" is sidebar-only (desktop), matching the
/// mockup's original 4-item bottom nav on tablet. [escribir] (campaign
/// editor, V2 design prototype §9a-9j) was added after that mockup shipped —
/// a top-level "write your own campaign" section, distinct from
/// `misHistorias` (reading what you've already played) and `explorar` (a
/// stub for reading what others have published), so it gets its own
/// destination rather than being buried in either.
enum HomeNavDestination { inicio, misHistorias, escribir, explorar, codice, ajustes }

extension HomeNavDestinationInfo on HomeNavDestination {
  String get label => switch (this) {
        HomeNavDestination.inicio => 'Inicio',
        HomeNavDestination.misHistorias => 'Mis historias',
        HomeNavDestination.escribir => 'Escribir',
        HomeNavDestination.explorar => 'Explorar',
        HomeNavDestination.codice => 'El Códice',
        HomeNavDestination.ajustes => 'Ajustes',
      };

  IconData get icon => switch (this) {
        HomeNavDestination.inicio => Icons.home_outlined,
        HomeNavDestination.misHistorias => Icons.library_books_outlined,
        HomeNavDestination.escribir => Icons.edit_note_outlined,
        HomeNavDestination.explorar => Icons.explore_outlined,
        HomeNavDestination.codice => Icons.menu_book_outlined,
        HomeNavDestination.ajustes => Icons.settings_outlined,
      };
}

/// One world row in the sidebar's "Mundos" list — name, its own accent dot
/// (`WorldTheme.forWorld(world).accent`), and how many stories the account
/// has started there (0 renders as "—", matching the mockup's dim/empty
/// worlds).
class HomeWorldEntry {
  const HomeWorldEntry({required this.name, required this.accent, required this.count});

  final String name;
  final Color accent;
  final int count;
}

/// Persistent left nav for the desktop home layout (V2 design prototype
/// §8a): brand row, the 5 [HomeNavDestination]s, a "Mundos" list, and an
/// account row at the bottom. Pure presentation — [onSelect] decides what
/// each destination actually does (including "Explorar", which the caller
/// wires to an inert "todavía no está disponible" snackbar today).
class HomeSidebar extends StatelessWidget {
  const HomeSidebar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.worlds,
    required this.accountInitial,
    required this.accountName,
    required this.accountSubtitle,
  });

  final HomeNavDestination current;
  final ValueChanged<HomeNavDestination> onSelect;
  final List<HomeWorldEntry> worlds;
  final String accountInitial;
  final String accountName;
  final String accountSubtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 236,
      padding: const EdgeInsets.symmetric(vertical: AetherSpace.xl, horizontal: AetherSpace.lg),
      decoration: const BoxDecoration(
        color: AetherColors.void_,
        border: Border(right: BorderSide(color: AetherColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 24),
              const SizedBox(width: AetherSpace.sm),
              const Flexible(
                child: Text(
                  'Aetherbook',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Marcellus',
                      fontSize: 18,
                      color: AetherColors.goldBright,
                      letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AetherSpace.xl),
          // A scrollable Expanded, not a bare list + Spacer: 6 nav
          // destinations plus a long "Mundos" list can outgrow the sidebar's
          // fixed viewport height at a large OS text-scale setting (V2 Stage
          // 8) — this section scrolls internally instead of overflowing the
          // outer Column, so the account row below always stays put.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final destination in HomeNavDestination.values)
                    _NavRow(
                      destination: destination,
                      selected: destination == current,
                      onTap: () => onSelect(destination),
                    ),
                  if (worlds.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AetherSpace.sm, AetherSpace.xl, AetherSpace.sm, AetherSpace.sm),
                      child: Text('MUNDOS',
                          style: AetherType.overline.copyWith(fontSize: 9, letterSpacing: 2)),
                    ),
                    for (final world in worlds) _WorldRow(world: world),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AetherColors.hairline),
          const SizedBox(height: AetherSpace.md),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AetherColors.gold.withValues(alpha: 0.16),
                  border: Border.all(color: AetherColors.gold.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Text(accountInitial,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AetherColors.goldBright)),
              ),
              const SizedBox(width: AetherSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(accountName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AetherColors.goldSoft),
                        overflow: TextOverflow.ellipsis),
                    Text(accountSubtitle,
                        style: AetherType.caption.copyWith(fontSize: 10, color: AetherColors.parchmentFaint)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.destination, required this.selected, required this.onTap});

  final HomeNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm + 2),
        decoration: BoxDecoration(
          color: selected ? AetherColors.gold.withValues(alpha: 0.12) : null,
          border: selected ? Border.all(color: AetherColors.gold.withValues(alpha: 0.28)) : null,
          borderRadius: AetherRadius.allMd,
        ),
        child: Row(
          children: [
            Icon(destination.icon,
                size: 19, color: selected ? AetherColors.goldBright : AetherColors.parchmentFaint),
            const SizedBox(width: AetherSpace.md),
            Expanded(
              child: Text(
                destination.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AetherColors.goldBright : AetherColors.parchmentDim,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldRow extends StatelessWidget {
  const _WorldRow({required this.world});

  final HomeWorldEntry world;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AetherSpace.sm, vertical: 5),
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: world.accent, shape: BoxShape.circle)),
          const SizedBox(width: AetherSpace.sm),
          Expanded(
            child: Text(world.name,
                style: AetherType.label.copyWith(fontSize: 12, color: AetherColors.parchmentDim),
                overflow: TextOverflow.ellipsis),
          ),
          Text(world.count > 0 ? '${world.count}' : '—',
              style: AetherType.caption.copyWith(fontSize: 11, color: AetherColors.parchmentFaint)),
        ],
      ),
    );
  }
}
