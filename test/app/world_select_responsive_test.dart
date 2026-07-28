// V2 §8a/§8b/§2a: WorldSelectScreen is one screen with 3 chrome modes
// decided by viewport width (AetherBreakpoints) — mobile keeps its original
// single-column shape, tablet adds a bottom nav, desktop adds a sidebar.
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/widgets/home_bottom_nav.dart';
import 'package:aetherbook/app/widgets/home_sidebar.dart';
import 'package:aetherbook/app/world_select_screen.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => World(
        slug: slug,
        name: 'Mundo $slug',
        theme: slug,
        tone: 'neutro',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'voluntad',
        startingCharacter: const Character(
            name: 'Protagonista', level: 1, exp: 0, attributes: {}, resources: {}),
        seedNarration: '',
        seedChoices: const [],
      );
}

GameController _newController() => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
    );

Future<void> _pumpAt(WidgetTester tester, Size size, {double textScale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    // `disableAnimations: true` stops `AetherBackground`'s never-ending
    // particle drift so a fixed pump count is enough to settle — same
    // gotcha `create_story_screen_test.dart` hit.
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    ),
    child: MaterialApp(
      home: WorldSelectScreen(controller: _newController()),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('WorldSelectScreen responsive chrome', () {
    testWidgets('mobile (< 700px): no sidebar, no bottom nav, shows "Elige tu historia"',
        (tester) async {
      await _pumpAt(tester, const Size(600, 1000));

      expect(find.byType(HomeSidebar), findsNothing);
      expect(find.byType(HomeBottomNav), findsNothing);
      expect(find.text('Elige tu historia'), findsOneWidget);
    });

    testWidgets('tablet (700-1099px): bottom nav, no sidebar', (tester) async {
      await _pumpAt(tester, const Size(800, 1100));

      expect(find.byType(HomeBottomNav), findsOneWidget);
      expect(find.byType(HomeSidebar), findsNothing);
      // Module cards still present, just laid out differently.
      expect(find.text('Historias completas'), findsOneWidget);
    });

    testWidgets('desktop (>= 1100px): sidebar, no bottom nav', (tester) async {
      await _pumpAt(tester, const Size(1280, 900));

      expect(find.byType(HomeSidebar), findsOneWidget);
      expect(find.byType(HomeBottomNav), findsNothing);
      expect(find.text('Historias completas'), findsOneWidget);
    });

    testWidgets('desktop sidebar "Mis historias" nav opens MyStoriesScreen', (tester) async {
      await _pumpAt(tester, const Size(1280, 900));

      await tester.tap(find.text('Mis historias'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mis historias'), findsWidgets); // sidebar nav + screen title
      // MyStoriesScreen's filter tab — at this (desktop) width its chips
      // carry a count too (V2 §4d, Stage V), so the label alone isn't "Todas".
      expect(find.textContaining('Todas'), findsOneWidget);
    });

    testWidgets('desktop sidebar "Explorar" shows a coming-soon snackbar, not a crash',
        (tester) async {
      await _pumpAt(tester, const Size(1280, 900));

      await tester.tap(find.text('Explorar'));
      await tester.pump();

      expect(find.text('Todavía no está disponible.'), findsOneWidget);
    });
  });

  group('text-scale accessibility (V2 Stage 8)', () {
    for (final scale in [1.3, 1.5, 2.0]) {
      testWidgets(
          'the module grid (childAspectRatio-fixed cells) reflows without '
          'overflowing at textScale $scale, tablet width', (tester) async {
        await _pumpAt(tester, const Size(800, 1100), textScale: scale);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'the module grid reflows without overflowing at textScale $scale, '
          'desktop width', (tester) async {
        await _pumpAt(tester, const Size(1280, 900), textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
