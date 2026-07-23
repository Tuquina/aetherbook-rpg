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
    // A resolved-outcome chip is now visible.
    expect(find.textContaining('vs 12'), findsOneWidget);
  });
}
