import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'home_sidebar.dart';

/// Bottom nav bar for the tablet home layout (V2 design prototype §8b) —
/// 4 destinations, no "Ajustes" (sidebar-only on desktop, matching the
/// mockup exactly).
class HomeBottomNav extends StatelessWidget {
  const HomeBottomNav({super.key, required this.current, required this.onSelect});

  static const _destinations = [
    HomeNavDestination.inicio,
    HomeNavDestination.misHistorias,
    HomeNavDestination.explorar,
    HomeNavDestination.codice,
  ];

  final HomeNavDestination current;
  final ValueChanged<HomeNavDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    // This bar has a fixed height (below) with no room to grow, the same
    // constraint every bottom-nav pattern runs into — Flutter's own
    // `BottomNavigationBar` caps how far its labels scale for exactly this
    // reason (V2 Stage 8). 1.3x still reads clearly larger for someone who
    // asked for bigger text; anything past that would need a taller bar
    // instead of a text clamp, at which point it's a difference from the
    // rest of the app that grows without bound elsewhere.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Container(
        height: 76,
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(
          color: Color(0xE00E0C0B),
          border: Border(top: BorderSide(color: AetherColors.hairline)),
        ),
        child: Row(
          children: [
            for (final destination in _destinations)
              // Expanded, not spaceAround: at a large OS text-scale setting
              // "Mis historias" (the longest label) no longer fits its
              // natural, unconstrained width four times over on a tablet
              // viewport (V2 Stage 8) -- an equal-width column per
              // destination gives each label somewhere to shrink/ellipsize
              // into instead of overflowing the Row.
              Expanded(
                child: _BottomNavItem(
                  destination: destination,
                  selected: destination == current,
                  onTap: () => onSelect(destination),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.destination, required this.selected, required this.onTap});

  final HomeNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AetherColors.goldBright : AetherColors.parchmentFaint;
    return InkWell(
      onTap: onTap,
      borderRadius: AetherRadius.allMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AetherSpace.md, vertical: AetherSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: 23, color: color),
            const SizedBox(height: 5),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
