import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/app/design/world_theme.dart';
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

  group('AetherBackground texture (V2 §4a, Stage T)', () {
    BoxDecoration decorationOf(WidgetTester tester) => tester
        .widget<DecoratedBox>(find
            .descendant(
                of: find.byType(AetherBackground), matching: find.byType(DecoratedBox))
            .first)
        .decoration as BoxDecoration;

    int overlayPainterCount(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.descendant(
            of: find.byType(AetherBackground), matching: find.byType(CustomPaint)))
        .length;

    testWidgets('null texture renders the original radial gradient, no overlay',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(particles: false, child: SizedBox())));
      await tester.pump();

      expect(decorationOf(tester).gradient, isA<RadialGradient>());
      expect(overlayPainterCount(tester), 0);
    });

    testWidgets('radialWarm renders the same radial gradient, no overlay',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(
              particles: false, texture: WorldTextureKind.radialWarm, child: SizedBox())));
      await tester.pump();

      expect(decorationOf(tester).gradient, isA<RadialGradient>());
      expect(overlayPainterCount(tester), 0);
    });

    testWidgets('fog keeps the radial gradient and adds one overlay painter',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(
              particles: false, texture: WorldTextureKind.fog, child: SizedBox())));
      await tester.pump();

      expect(decorationOf(tester).gradient, isA<RadialGradient>());
      expect(overlayPainterCount(tester), 1);
    });

    testWidgets('hardDiagonal swaps in a linear gradient with hard stops, no overlay',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(
              particles: false, texture: WorldTextureKind.hardDiagonal, child: SizedBox())));
      await tester.pump();

      final gradient = decorationOf(tester).gradient as LinearGradient;
      expect(gradient.stops, [0.0, 0.4, 0.4, 1.0]); // hard stop: 0.4 repeats
      expect(overlayPainterCount(tester), 0);
    });

    testWidgets('scanline swaps in a linear gradient and adds one overlay painter',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(
              particles: false, texture: WorldTextureKind.scanline, child: SizedBox())));
      await tester.pump();

      expect(decorationOf(tester).gradient, isA<LinearGradient>());
      expect(overlayPainterCount(tester), 1);
    });

    testWidgets('grain swaps in a linear gradient and adds one overlay painter',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
          home: AetherBackground(
              particles: false, texture: WorldTextureKind.grain, child: SizedBox())));
      await tester.pump();

      expect(decorationOf(tester).gradient, isA<LinearGradient>());
      expect(overlayPainterCount(tester), 1);
    });
  });
}
