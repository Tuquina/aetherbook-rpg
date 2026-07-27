import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/app/widgets/atmosphere.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AetherBackground base/accent (V2 per-world theming, §4a-4d)', () {
    testWidgets('defaults to the global ink/gold gradient when unset',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(particles: false, child: SizedBox())));
      await tester.pump();

      final box = tester.widget<DecoratedBox>(find
          .descendant(of: find.byType(AetherBackground), matching: find.byType(DecoratedBox))
          .first);
      final gradient = (box.decoration as BoxDecoration).gradient as RadialGradient;

      expect(gradient.colors[1], AetherColors.ink);
      expect(gradient.colors[2], AetherColors.void_);
    });

    testWidgets('a world\'s base color replaces the mid gradient stop',
        (tester) async {
      const themedBase = Color(0xFF0F1D1A); // Xianxia's proposed theme base
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(
              particles: false, base: themedBase, child: SizedBox())));
      await tester.pump();

      final box = tester.widget<DecoratedBox>(find
          .descendant(of: find.byType(AetherBackground), matching: find.byType(DecoratedBox))
          .first);
      final gradient = (box.decoration as BoxDecoration).gradient as RadialGradient;

      expect(gradient.colors[1], themedBase);
      // The deepest anchor never varies by world, by design.
      expect(gradient.colors[2], AetherColors.void_);
    });
  });
}
