import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// Shared bottom-sheet chrome — drag handle, title + close button, and a
/// height-capped scrollable body — used by every V2 bottom sheet (character
/// sheet, inventory, story menu) so they read as one family instead of each
/// reinventing its own frame (V2 design prototype §1a's shared `sheetOpen`
/// shell, which switches only its inner content per sheet).
///
/// [child] is expected to size itself to whatever content it holds (a
/// `Column` with `mainAxisSize: MainAxisSize.min`, or a scrollable like
/// `ListView` that's happy to take whatever finite height it's given) —
/// this shell provides the bound, not the scrolling itself.
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.child,
    this.maxHeightFraction = 0.78,
  });

  final String title;
  final Widget child;

  /// Fraction of the screen height this sheet may grow to before its own
  /// content has to scroll internally.
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AetherColors.surface,
            borderRadius: const BorderRadius.vertical(top: AetherRadius.lg),
            border: Border.all(color: AetherColors.hairlineStrong),
            boxShadow: AetherShadow.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AetherSpace.sm),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AetherColors.hairlineStrong,
                  borderRadius: AetherRadius.allPill,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AetherSpace.xl, AetherSpace.md, AetherSpace.md, AetherSpace.xs),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: AetherType.title)),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close_rounded,
                          color: AetherColors.parchmentDim, size: 20),
                    ),
                  ],
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
