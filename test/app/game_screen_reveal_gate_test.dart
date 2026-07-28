// Regression test for a pre-existing bug (found while validating V2 §1c's
// wide layout against a genuinely mobile viewport, confirmed present on
// unmodified code too): `_armRevealGate`'s check of `maxScrollExtent` used
// to run exactly once, right after a turn's narration changed. For a turn
// whose content lands right at the edge of the viewport height, the
// scrollable could still be settling into its final extent at that single
// check -- reading a stale, still-nonzero value, deciding not to reveal,
// and then never getting another chance: with nothing to actually scroll,
// no user gesture could ever trigger a re-check either, permanently
// stranding the choices bar behind "Sigue leyendo". Fixed by also
// re-running the check on every `ScrollMetricsNotification`, not just once.
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
          attributes: {'voluntad': 3},
          resources: {},
        ),
        seedNarration: 'Todo comienza.',
        seedChoices: const ['Avanzar'],
      );
}

void main() {
  testWidgets(
      'a short critical-success turn (FateRoll shown, narration short '
      'enough to fit) auto-reveals its choices at a real mobile width, '
      'without needing to scroll first', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      dice: const FixedDice(20), // natural 20 -> always a critical success
    );

    await tester.pumpWidget(
        MaterialApp(home: GameScreen(controller: controller, worldSlug: 'reveal_gate_test')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Avanzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Let any late-settling scroll metrics notifications land.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CHEQUEO DE VOLUNTAD'), findsOneWidget); // FateRoll rendered
    expect(find.text('Sigue leyendo'), findsNothing);
    expect(find.text('Consolidar el avance en meditación'), findsOneWidget);
  });
}
