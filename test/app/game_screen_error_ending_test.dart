// V2 design prototype §1b: the narrator-error retry panel and the
// "final descubierto" interstitial before the epilogue. Neither had a
// widget test before this file.
import 'package:aetherbook/adapters/narrator/http_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/epilogue_beat.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/vow.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Throws on the first [narrate] call, then answers normally — enough to
/// exercise `_NarratorErrorPanel`'s "Reintentar" without a real network call.
class _FlakyNarrator implements NarratorPort {
  int calls = 0;

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    calls++;
    if (calls == 1) {
      throw Exception('simulated narrator outage');
    }
    return const NarratorResponse(
      narration: 'El camino se aclara.',
      tone: 'sereno',
      suggestedChoices: [],
      stateDeltas: [],
      imagePrompt: '',
    );
  }
}

/// Throws a [NarratorHttpException] carrying a real `attemptCount`, once —
/// exercises `_NarratorErrorPanel`'s Stage-7 attempt-count line without a
/// real network call, mirroring `_FlakyNarrator` but with the specific
/// exception shape the Edge Function's 502 "all providers failed" body
/// produces.
class _AllProvidersFailedNarrator implements NarratorPort {
  int calls = 0;

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    calls++;
    if (calls == 1) {
      throw NarratorHttpException(
        'Edge Function responded 502: all narrator providers failed',
        statusCode: 502,
        attemptCount: 2,
      );
    }
    return const NarratorResponse(
      narration: 'El camino se aclara.',
      tone: 'sereno',
      suggestedChoices: [],
      stateDeltas: [],
      imagePrompt: '',
    );
  }
}

World _freeformWorld() => World(
      slug: 'error_test',
      name: 'Mundo de prueba',
      theme: 'test',
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
      seedNarration: 'Todo comienza.',
      seedChoices: const ['Avanzar'],
    );

const _endingGraph = StoryGraph(
  startNodeId: 'climax',
  nodes: {
    'climax': ResolutionNode(
      id: 'climax',
      narration: 'El momento de decidir llegó.',
      epilogueNodeId: 'epilogo',
      endings: [
        Ending(
          id: 'final_luz',
          visibleChoice: 'Elegir la luz',
          baseDifficulty: 1, // trivially met -- deterministic success
          successReveals: ['La luz gana.'],
        ),
      ],
    ),
    'epilogo': ResolutionNode(
      id: 'epilogo',
      epilogueBeats: [
        EpilogueBeat(movement: 'cierre', gate: AlwaysGate(), text: 'Todo termina.'),
      ],
    ),
  },
);

World _endingWorld({String? vowId}) => World(
      slug: 'ending_test',
      name: 'Mundo de prueba',
      theme: 'test',
      tone: 'neutro',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 99,
      criticalMargin: 5,
      primaryAttribute: 'voluntad',
      storyGraph: _endingGraph,
      vows: const [Vow(id: 'no_ceder', text: 'No voy a ceder.')],
      startingCharacter: Character(
        name: 'Protagonista',
        level: 3,
        exp: 0,
        attributes: const {'voluntad': 1},
        resources: const {},
        vowId: vowId,
      ),
      seedNarration: '',
      seedChoices: const [],
      aiRuntimeRequired: false,
      allowFreeText: false,
    );

class _FakeWorldRepository implements WorldRepositoryPort {
  const _FakeWorldRepository(this.world);
  final World world;

  @override
  Future<World> loadWorld(String slug) async => world;
}

class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('NarratorPort.narrate must never be called for an AI-free world');
  }
}

/// Forces the mobile chrome (< `AetherBreakpoints.tablet`) -- these tests
/// are about the error panel/ending overlay themselves, not about the wide
/// split-view (V2 §1c), and the default 800x600 test surface now lands in
/// split-view since it's >= 700 wide.
Future<void> _pumpMobile(WidgetTester tester, GameController controller, String worldSlug) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller, worldSlug: worldSlug)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets(
      'a failed narrator call shows the error panel; "Reintentar" replays '
      'the same action and succeeds', (tester) async {
    final narrator = _FlakyNarrator();
    final controller = GameController(
      worldRepository: _FakeWorldRepository(_freeformWorld()),
      narrator: narrator,
      dice: const FixedDice(10),
    );

    await _pumpMobile(tester, controller, 'error_test');

    await tester.tap(find.text('Avanzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('EL NARRADOR NO RESPONDE'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(narrator.calls, 1);
    // A plain exception (not NarratorHttpException) carries no attempt
    // detail (V2 Stage 7) -- no attempt-count line should render.
    expect(controller.narratorAttemptCount, isNull);
    expect(find.textContaining('Lo intentamos'), findsNothing);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(narrator.calls, 2);
    expect(controller.error, isNull);
    expect(find.text('EL NARRADOR NO RESPONDE'), findsNothing);
    expect(find.textContaining('El camino se aclara.'), findsOneWidget);
  });

  testWidgets(
      'a 502 "all providers failed" response shows how many were tried '
      '(V2 Stage 7)', (tester) async {
    final narrator = _AllProvidersFailedNarrator();
    final controller = GameController(
      worldRepository: _FakeWorldRepository(_freeformWorld()),
      narrator: narrator,
      dice: const FixedDice(10),
    );

    await _pumpMobile(tester, controller, 'error_test');

    await tester.tap(find.text('Avanzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('EL NARRADOR NO RESPONDE'), findsOneWidget);
    expect(controller.narratorAttemptCount, 2);
    expect(find.text('Lo intentamos 2 veces, con fuentes distintas, sin éxito.'),
        findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.narratorAttemptCount, isNull);
    expect(find.textContaining('El camino se aclara.'), findsOneWidget);
  });

  testWidgets(
      '"Elegir otra vez" clears the error without retrying, returning to '
      'the normal choices', (tester) async {
    final narrator = _FlakyNarrator();
    final controller = GameController(
      worldRepository: _FakeWorldRepository(_freeformWorld()),
      narrator: narrator,
      dice: const FixedDice(10),
    );

    await _pumpMobile(tester, controller, 'error_test');

    await tester.tap(find.text('Avanzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('EL NARRADOR NO RESPONDE'), findsOneWidget);

    await tester.tap(find.text('Elegir otra vez'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(narrator.calls, 1); // never retried
    expect(controller.error, isNull);
    expect(find.text('EL NARRADOR NO RESPONDE'), findsNothing);
    expect(find.text('Avanzar'), findsOneWidget);
  });

  testWidgets(
      'choosing an ending shows the reveal overlay with turn/level/vow '
      'stats before the epilogue text, dismissed by "Leer el epílogo"',
      (tester) async {
    final controller = GameController(
      worldRepository: _FakeWorldRepository(_endingWorld(vowId: 'no_ceder')),
      narrator: const _ForbiddenNarrator(),
      dice: const FixedDice(20),
    );

    await _pumpMobile(tester, controller, 'ending_test');

    await tester.tap(find.text('Elegir la luz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('FINAL DESCUBIERTO · 1 DE 1'), findsOneWidget);
    expect(find.text('Elegir la luz'), findsWidgets); // overlay title + card
    expect(find.text('Leer el epílogo'), findsOneWidget);
    expect(find.text('«No voy a ceder.»'), findsOneWidget);
    expect(find.text('Sostenido hasta el final'), findsOneWidget);
    // The epilogue narration is already resolved underneath, just not
    // revealed to the reader until they dismiss the overlay.
    expect(find.textContaining('Todo termina.'), findsOneWidget);

    await tester.tap(find.text('Leer el epílogo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('FINAL DESCUBIERTO · 1 DE 1'), findsNothing);
    expect(find.textContaining('Todo termina.'), findsOneWidget);
  });
}
