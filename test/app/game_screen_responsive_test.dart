// V2 design prototype §1c: GameScreen gains a wide split-view chrome at
// AetherBreakpoints.tablet (700) and up -- mobile keeps its original
// single-column, scroll-gated shape below that.
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => World(
        slug: slug,
        name: 'Mundo de prueba',
        theme: slug,
        tone: 'neutro',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'voluntad',
        startingCharacter: const Character(
          name: 'Protagonista',
          level: 1,
          exp: 0,
          attributes: {'voluntad': 1},
          resources: {},
        ),
        seedNarration: 'Un texto corto que no necesita scroll.',
        seedChoices: const ['Avanzar', 'Retroceder'],
      );
}

GameController _newController() => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      dice: const FixedDice(10),
    );

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: GameScreen(controller: _newController(), worldSlug: 'responsive_test'),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('GameScreen responsive chrome', () {
    testWidgets(
        'mobile (< 700px): world name appears once (StatusBar only, no '
        'split-view scene panel)', (tester) async {
      await _pumpAt(tester, const Size(600, 1400));

      expect(find.text('MUNDO DE PRUEBA'), findsOneWidget);
    });

    testWidgets(
        'wide (>= 700px): world name appears twice (StatusBar + '
        '_ScenePanel), and choices are always visible with no scroll gate',
        (tester) async {
      await _pumpAt(tester, const Size(1100, 800));

      expect(find.text('MUNDO DE PRUEBA'), findsNWidgets(2));
      expect(find.text('Avanzar'), findsOneWidget);
      expect(find.text('Retroceder'), findsOneWidget);
    });
  });
}
