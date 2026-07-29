import 'package:flutter/material.dart';

/// Centers [child] vertically within whatever height it's given, but scrolls
/// instead of overflowing if [child] ends up taller than that — the same
/// "no `Spacer`/`Expanded` inside a scrollable's unbounded main axis" trick
/// `SplashScreen` already relied on (see its own long-form comment), pulled
/// out so every desktop split-layout panel (a `BrandLockup` on one side, a
/// bordered card on the other) can use it instead of duplicating the
/// `LayoutBuilder` + `ConstrainedBox(minHeight:)` dance.
class ScrollableCentered extends StatelessWidget {
  const ScrollableCentered({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
