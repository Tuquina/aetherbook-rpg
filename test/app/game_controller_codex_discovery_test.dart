// V2 §1a: a curated node's `codex_reveals` marks Códice glossary entries
// (lugares/términos) discovered the moment the graph advances there --
// synthesized as ordinary `flag` deltas in `GameController._resolveTurn`
// (`codex_discovered_<id>`), never a new StateDeltaType, never proposed by
// the narrator.
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('NarratorPort.narrate must never be called for an AI-free world');
  }
}

const _graph = StoryGraph(
  startNodeId: 'inicio',
  nodes: {
    'inicio': FixedAnchorNode(
      id: 'inicio',
      narration: 'Estás en el umbral.',
      choices: [
        StoryChoice(
          label: 'Entrar a la Casa de Tinta',
          targetNodeId: 'casa_de_tinta',
          resultText: 'Cruzás el umbral.',
        ),
      ],
    ),
    'casa_de_tinta': FixedAnchorNode(
      id: 'casa_de_tinta',
      narration: 'Estanterías cubiertas de manuscritos.',
      codexReveals: ['lugar:casa_de_tinta', 'termino:ledger_debt'],
    ),
  },
);

World _worldWith(StoryGraph graph) => World(
      slug: 'codex_discovery_test',
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

void main() {
  test('advancing to a node with codexReveals marks each entry discovered', () async {
    final controller = GameController(
      worldRepository: _FakeWorldRepository(_worldWith(_graph)),
      narrator: const _ForbiddenNarrator(),
      dice: const FixedDice(10),
    );
    await controller.start('codex_discovery_test');

    expect(controller.character!.flag('codex_discovered_lugar:casa_de_tinta'), isFalse);
    expect(controller.character!.flag('codex_discovered_termino:ledger_debt'), isFalse);

    await controller.chooseStoryChoice(
      (controller.currentNode as FixedAnchorNode).choices.single,
    );

    expect(controller.character!.flag('codex_discovered_lugar:casa_de_tinta'), isTrue);
    expect(controller.character!.flag('codex_discovered_termino:ledger_debt'), isTrue);
  });

  test('a node with no codexReveals discovers nothing', () async {
    final controller = GameController(
      worldRepository: _FakeWorldRepository(_worldWith(_graph)),
      narrator: const _ForbiddenNarrator(),
      dice: const FixedDice(10),
    );
    await controller.start('codex_discovery_test');

    // Still at 'inicio', which declares no codex_reveals of its own.
    expect(controller.character!.flags.keys, isEmpty);
  });
}
