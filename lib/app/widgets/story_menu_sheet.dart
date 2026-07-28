import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'sheet_shell.dart';

/// The story-menu bottom sheet reachable from `GameScreen`'s back arrow (V2
/// design prototype §1a's `isMenu` sheet) — replaces the old direct
/// "back arrow instantly leaves the story" behavior with an explicit choice:
/// keep reading, go back to the library, or abandon this story outright.
/// [onBackToLibrary] and [onAbandon] are plain callbacks — this widget owns
/// no navigation or confirmation logic itself, both stay with the caller
/// (`GameScreen`), same as the rest of its confirm-sheet call sites.
Future<void> showStoryMenuSheet(
  BuildContext context, {
  required VoidCallback onBackToLibrary,
  required VoidCallback onAbandon,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AetherColors.void_.withValues(alpha: 0.72),
    isScrollControlled: true,
    builder: (_) => SheetShell(
      title: 'Tu historia',
      child: _StoryMenuBody(onBackToLibrary: onBackToLibrary, onAbandon: onAbandon),
    ),
  );
}

class _StoryMenuBody extends StatelessWidget {
  const _StoryMenuBody({required this.onBackToLibrary, required this.onAbandon});

  final VoidCallback onBackToLibrary;
  final VoidCallback onAbandon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AetherSpace.xl, AetherSpace.sm, AetherSpace.xl, AetherSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu progreso ya está guardado. Puedes volver cuando quieras: esta historia te espera en el mismo punto.',
            style: AetherType.body.copyWith(color: AetherColors.parchmentDim),
          ),
          const SizedBox(height: AetherSpace.lg),
          _MenuRow(
            icon: Icons.menu_book_rounded,
            label: 'Seguir leyendo',
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AetherSpace.sm),
          _MenuRow(
            icon: Icons.library_books_rounded,
            label: 'Volver a mis historias',
            onTap: () {
              Navigator.of(context).pop();
              onBackToLibrary();
            },
          ),
          const SizedBox(height: AetherSpace.sm),
          _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Abandonar esta historia',
            destructive: true,
            onTap: () {
              Navigator.of(context).pop();
              onAbandon();
            },
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AetherColors.failure : AetherColors.goldSoft;
    return Material(
      color: destructive ? AetherColors.failureDim : AetherColors.surfaceRaised,
      borderRadius: AetherRadius.allMd,
      child: InkWell(
        borderRadius: AetherRadius.allMd,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AetherSpace.lg, vertical: AetherSpace.md),
          decoration: BoxDecoration(
            borderRadius: AetherRadius.allMd,
            border: Border.all(
              color: destructive
                  ? AetherColors.failure.withValues(alpha: 0.4)
                  : AetherColors.hairline,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: AetherSpace.md),
              Expanded(
                child: Text(label,
                    style: AetherType.label.copyWith(
                        color: destructive ? AetherColors.failure : AetherColors.parchment)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
