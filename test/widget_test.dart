import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory world repo so the widget test never touches asset bundles.
class _InMemoryWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => const World(
        slug: 'xianxia',
        name: 'El Sendero del Qi',
        theme: 'xianxia',
        tone: 'épico',
        systemPrompt: '',
        imageStyleSuffix: 'arte xianxia',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'espiritu',
        startingCharacter: Character(
          name: 'Discípulo',
          level: 1,
          exp: 0,
          attributes: {'espiritu': 2},
          resources: {'qi': 10},
        ),
        seedNarration: 'Comienza el sendero de piedra.',
        seedChoices: ['Meditar', 'Explorar', 'Leer'],
      );
}

void main() {
  testWidgets('plays a turn end-to-end against the fake narrator',
      (tester) async {
    final controller = GameController(
      worldRepository: _InMemoryWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      dice: const FixedDice(10), // 2 + 10 = 12 vs 12 -> deterministic success
    );

    await tester.pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
    await tester.pump(); // resolve start()
    await tester.pump(const Duration(milliseconds: 500)); // settle fade-in

    // Opening scene: seed narration and the world's choices are shown.
    expect(find.textContaining('sendero de piedra'), findsOneWidget);
    expect(find.text('Meditar'), findsOneWidget);

    // Choose an action -> resolve -> narrate -> render.
    await tester.tap(find.text('Meditar'));
    await tester.pump(); // kick off choose()
    await tester.pump(const Duration(milliseconds: 500)); // narrate + fade

    // The narration advanced and now reflects the chosen action.
    expect(find.textContaining('Meditar'), findsWidgets);
    // The Fate Roll reveal is now on screen (2 + d20 10 = 12 vs 12 -> ÉXITO).
    expect(find.textContaining('vs dificultad 12'), findsOneWidget);
    expect(find.text('ÉXITO'), findsOneWidget);
  });

  testWidgets(
      'reveals choices for an already-started controller with short opening '
      'prose, exactly how ChargenScreen hands off to GameScreen', (tester) async {
    // ChargenScreen awaits controller.start() itself and only then navigates
    // to GameScreen with an already-`isReady` controller — GameScreen never
    // sees the notifyListeners() call for that first turn, since it didn't
    // exist yet to be listening. A short seed narration (like this world's)
    // fits on screen without any scrolling, so if the "keep reading" reveal
    // gate isn't armed independently of that missed notification, the
    // player is stuck forever with no way to open it.
    final controller = GameController(
      worldRepository: _InMemoryWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      dice: const FixedDice(10),
    );
    await controller.start('xianxia');
    expect(controller.isReady, isTrue);

    await tester.pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('sendero de piedra'), findsOneWidget);
    expect(find.text('Meditar'), findsOneWidget,
        reason: 'choices must be revealed immediately for prose that never '
            'needed scrolling in the first place');
  });
}
