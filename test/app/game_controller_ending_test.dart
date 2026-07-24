// Covers GameController.availableEndings/chooseEnding — the climax
// mechanism (ResolutionNode.endings, Ending.difficultyFor, failure
// fallbacks, final technique granting, and advancing into a pure epilogue
// node's assembled beats) that xianxia_lianshu's existing coverage never
// exercised, since the vertical slice stops well before the ritual.
// An AI-free synthetic world (same pattern as
// game_controller_curated_no_ai_test.dart) so the produced narration is
// exactly `Ending.successReveals`/`costReveals` — no narrator output to
// account for.
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/ending_fallback.dart';
import 'package:aetherbook/core/narrative/epilogue_beat.dart';
import 'package:aetherbook/core/narrative/final_technique_rule.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('NarratorPort.narrate must never be called for an AI-free world');
  }
}

final _graph = StoryGraph(
  startNodeId: 'climax',
  nodes: {
    'climax': const ResolutionNode(
      id: 'climax',
      narration: 'El momento de decidir llegó.',
      epilogueNodeId: 'epilogo',
      finalTechniqueRules: [
        FinalTechniqueRule(gate: AlwaysGate(), techniqueId: 'tecnica_comun'),
      ],
      endings: [
        Ending(
          id: 'final_luz',
          visibleChoice: 'Elegir la luz',
          baseDifficulty: 10,
          successReveals: ['La luz gana.'],
          costReveals: ['Algo se apaga.'],
        ),
        Ending(
          id: 'final_oscuro',
          visibleChoice: 'Elegir la oscuridad',
          baseDifficulty: 10,
          successReveals: ['La oscuridad gana.'],
          costReveals: ['El costo es alto.'],
          failureCostOptions: ['pierde su nombre'],
          onFailureFallbacks: [
            EndingFallback(gate: AlwaysGate(), endingId: 'final_oscuro_fracturado'),
          ],
        ),
        Ending(
          id: 'final_secreto',
          visibleChoice: 'El final oculto',
          hardRequirement: FlagGate('saw_truth'),
        ),
      ],
    ),
    'epilogo': const ResolutionNode(
      id: 'epilogo',
      epilogueBeats: [
        EpilogueBeat(
          movement: 'cierre',
          gate: FlagGate('ending_final_luz'),
          text: 'Todo termina en luz.',
        ),
        EpilogueBeat(
          movement: 'cierre',
          gate: FlagGate('ending_final_oscuro_fracturado'),
          text: 'Todo termina fracturado.',
        ),
        EpilogueBeat(
          movement: 'cierre',
          gate: AlwaysGate(),
          text: 'El final llega de todos modos.',
        ),
      ],
    ),
  },
);

final _world = World(
  slug: 'climax_test',
  name: 'Mundo de prueba del clímax',
  theme: 'test',
  tone: 'neutro',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 99, // deliberately absurd -- endings never use this
  criticalMargin: 5,
  primaryAttribute: 'voluntad',
  storyGraph: _graph,
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
  @override
  Future<World> loadWorld(String slug) async => _world;
}

GameController _controllerWith(Dice dice) => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const _ForbiddenNarrator(),
      dice: dice,
    );

void main() {
  group('GameController.availableEndings', () {
    test('filters out an ending whose hard requirement is not met', () async {
      final controller = _controllerWith(const FixedDice(10));
      await controller.start('climax_test');

      final ids = controller.availableEndings.map((e) => e.id).toSet();
      expect(ids, {'final_luz', 'final_oscuro'});
      expect(ids.contains('final_secreto'), isFalse);
    });
  });

  group('GameController.chooseEnding — success', () {
    test('sets the ending flag, grants the technique, and advances into the '
        "epilogue's matching beat", () async {
      final controller = _controllerWith(const FixedDice(20)); // natural 20 -> always succeeds
      await controller.start('climax_test');

      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_luz');
      await controller.chooseEnding(ending);

      expect(controller.error, isNull);
      expect(controller.character!.flag('ending_final_luz'), isTrue);
      expect(controller.character!.varValue('final_technique_id'), 'tecnica_comun');
      expect(controller.narration, contains('La luz gana.'));
      expect(controller.narration, contains('Algo se apaga.'));

      expect(controller.currentNode!.id, 'epilogo');
      expect(controller.availableStoryChoices, isEmpty);
      expect(controller.availableEndings, isEmpty);
      expect(controller.narration, contains('Todo termina en luz.'));
      // The unrelated fallback-only beat must not also show.
      expect(controller.narration, isNot(contains('fracturado')));
    });
  });

  group('GameController.chooseEnding — failure with a fallback', () {
    test('redirects to the fallback ending id instead of undoing the scene',
        () async {
      final controller = _controllerWith(const FixedDice(1)); // natural 1 -> always fails
      await controller.start('climax_test');

      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_oscuro');
      await controller.chooseEnding(ending);

      expect(controller.error, isNull);
      // The attempted ending's own flag is NOT what gets set on failure --
      // the fallback's id is.
      expect(controller.character!.flag('ending_final_oscuro'), isFalse);
      expect(controller.character!.flag('ending_final_oscuro_fracturado'), isTrue);
      // A failed check still costs -- it doesn't reset the game or skip the
      // scene, same rule as every other check in the engine.
      expect(controller.narration, contains('El costo es alto.'));
      expect(controller.narration, contains('pierde su nombre'));

      expect(controller.currentNode!.id, 'epilogo');
      expect(controller.narration, contains('Todo termina fracturado.'));
    });
  });
}
