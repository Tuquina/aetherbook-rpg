// V2 Stage 4/5 (started early, alongside Stage 2's dialog consolidation):
// game_screen.dart's story-choice and ending confirmations moved from
// showDialog/AlertDialog to showConfirmSheet. Neither had a widget test
// exercising the confirmation UI itself before this file.
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/epilogue_beat.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
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
    fail('NarratorPort.narrate must never be called for an AI-free world');
  }
}

const _choiceGraph = StoryGraph(
  startNodeId: 'inicio',
  nodes: {
    'inicio': FixedAnchorNode(
      id: 'inicio',
      narration: 'Llegas a un cruce de caminos.',
      choices: [
        StoryChoice(
          label: 'Hablar con el anciano',
          targetNodeId: 'charla',
          resultText: 'Charlaste con el anciano.',
        ),
        StoryChoice(
          label: 'Quemar el puente',
          targetNodeId: 'quemado',
          resultText: 'El puente arde a tus espaldas.',
          requiresConfirmation: true,
          confirmationText: 'Si quemas el puente, no hay vuelta atrás.',
        ),
      ],
    ),
    'charla': FixedAnchorNode(
        id: 'charla', narration: 'El anciano te saluda con calma.', choices: []),
    'quemado': FixedAnchorNode(
        id: 'quemado', narration: 'Ya no puedes regresar por ahí.', choices: []),
  },
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
          baseDifficulty: 1, // trivially met by any roll -- deterministic success
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

World _worldWith(StoryGraph graph) => World(
      slug: 'confirm_sheet_test',
      name: 'Mundo de prueba',
      theme: 'test',
      tone: 'neutro',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 99,
      criticalMargin: 5,
      primaryAttribute: 'voluntad',
      storyGraph: graph,
      startingCharacter: const Character(
        name: 'Protagonista',
        level: 1,
        exp: 0,
        attributes: {'voluntad': 1},
        resources: {},
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

GameController _controllerWith(World world, Dice dice) => GameController(
      worldRepository: _FakeWorldRepository(world),
      narrator: const _ForbiddenNarrator(),
      dice: dice,
    );

void main() {
  testWidgets(
      'a choice with no requiresConfirmation resolves on a single tap, no sheet',
      (tester) async {
    final controller = _controllerWith(_worldWith(_choiceGraph), const FixedDice(10));

    await tester.pumpWidget(MaterialApp(
        home: GameScreen(controller: controller, worldSlug: 'confirm_sheet_test')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Hablar con el anciano'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('El anciano te saluda con calma'), findsOneWidget);
  });

  testWidgets(
      'a choice with requiresConfirmation shows a ConfirmSheet with its '
      'authored confirmationText, and does nothing until confirmed',
      (tester) async {
    final controller = _controllerWith(_worldWith(_choiceGraph), const FixedDice(10));

    await tester.pumpWidget(MaterialApp(
        home: GameScreen(controller: controller, worldSlug: 'confirm_sheet_test')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Quemar el puente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('no hay vuelta atrás'), findsOneWidget);
    expect(find.text('Confirmar'), findsOneWidget);

    // Cancel: nothing happens, still at the crossroads.
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Llegas a un cruce de caminos'), findsOneWidget);
    expect(find.text('Quemar el puente'), findsOneWidget);

    // Try again and actually confirm this time.
    await tester.tap(find.text('Quemar el puente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Ya no puedes regresar por ahí'), findsOneWidget);
  });

  testWidgets(
      'choosing an ending shows a ConfirmSheet titled with the ending\'s '
      'visibleChoice, and only resolves it after confirming', (tester) async {
    final controller =
        _controllerWith(_worldWith(_endingGraph), const FixedDice(10));

    await tester.pumpWidget(MaterialApp(
        home: GameScreen(controller: controller, worldSlug: 'confirm_sheet_test')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Elegir la luz'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Elegir la luz'), findsWidgets); // sheet title + the choice card
    expect(find.textContaining('no hay vuelta atrás'), findsOneWidget);
    expect(controller.character!.flag('ending_final_luz'), isFalse);

    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.character!.flag('ending_final_luz'), isTrue);
    expect(find.textContaining('Todo termina'), findsOneWidget);
  });
}
