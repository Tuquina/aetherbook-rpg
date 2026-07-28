// V2 Stage 5: the back arrow now opens a story-menu sheet (seguir leyendo /
// volver a mis historias / abandonar esta historia) instead of leaving the
// story on a single tap.
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/app/world_select_screen.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('NarratorPort.narrate must never be called in this test');
  }
}

const _world = World(
  slug: 'story_menu_test',
  name: 'Mundo de prueba',
  theme: 'test',
  tone: 'neutro',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'voluntad',
  startingCharacter: Character(
      name: 'Protagonista', level: 1, exp: 0, attributes: {'voluntad': 1}, resources: {}),
  seedNarration: 'El principio de la historia.',
  seedChoices: ['Avanzar'],
);

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => _world;
}

GameController _newController() => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const _ForbiddenNarrator(),
      dice: const FixedDice(10),
    );

Future<void> _pumpGame(WidgetTester tester, GameController controller) async {
  await tester.pumpWidget(MaterialApp(
      home: GameScreen(controller: controller, worldSlug: 'story_menu_test')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _openStoryMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menú de la historia'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the back arrow opens the story menu instead of leaving immediately',
      (tester) async {
    final controller = _newController();
    await _pumpGame(tester, controller);

    await _openStoryMenu(tester);

    expect(find.text('Tu historia'), findsOneWidget);
    expect(find.text('Seguir leyendo'), findsOneWidget);
    expect(find.text('Volver a mis historias'), findsOneWidget);
    expect(find.text('Abandonar esta historia'), findsOneWidget);
    // Still on the game screen, session untouched.
    expect(controller.isReady, isTrue);
  });

  testWidgets('"Seguir leyendo" just dismisses the sheet', (tester) async {
    final controller = _newController();
    await _pumpGame(tester, controller);
    await _openStoryMenu(tester);

    await tester.tap(find.text('Seguir leyendo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tu historia'), findsNothing);
    expect(find.textContaining('El principio de la historia'), findsOneWidget);
    expect(controller.isReady, isTrue);
  });

  testWidgets('"Volver a mis historias" navigates to WorldSelectScreen, session kept',
      (tester) async {
    final controller = _newController();
    await _pumpGame(tester, controller);
    await _openStoryMenu(tester);

    await tester.tap(find.text('Volver a mis historias'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldSelectScreen), findsOneWidget);
    // The session is still in memory — WorldSelectScreen's continue-hero can
    // resume it, unlike an abandoned one.
    expect(controller.isReady, isTrue);
  });

  testWidgets(
      '"Abandonar esta historia" asks for confirmation and does nothing until confirmed',
      (tester) async {
    final controller = _newController();
    await _pumpGame(tester, controller);
    await _openStoryMenu(tester);

    await tester.tap(find.text('Abandonar esta historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('¿Abandonar esta historia?'), findsOneWidget);
    expect(controller.isReady, isTrue);

    // Cancel: the session survives, still on the game screen.
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.isReady, isTrue);
    expect(find.textContaining('El principio de la historia'), findsOneWidget);
  });

  testWidgets(
      'confirming the abandon clears the active session and navigates to WorldSelectScreen',
      (tester) async {
    final controller = _newController();
    await _pumpGame(tester, controller);
    await _openStoryMenu(tester);

    await tester.tap(find.text('Abandonar esta historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Abandonar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldSelectScreen), findsOneWidget);
    // The session was actually cleared, not just navigated away from — a
    // "continue" hero on WorldSelectScreen must not offer it back.
    expect(controller.isReady, isFalse);
    expect(controller.world, isNull);
  });
}
