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
    return Container(
      height: 76,
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Color(0xE00E0C0B),
        border: Border(top: BorderSide(color: AetherColors.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final destination in _destinations)
            _BottomNavItem(
              destination: destination,
              selected: destination == current,
              onTap: () => onSelect(destination),
            ),
        ],
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
