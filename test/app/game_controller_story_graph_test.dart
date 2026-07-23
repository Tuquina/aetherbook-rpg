import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/create_character.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/narrative/hub_activity.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/character_origin.dart';
import 'package:aetherbook/core/world/resource_formula.dart';
import 'package:aetherbook/core/world/vow.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// A narrator that never proposes any delta of its own — lets these tests
/// assert on the *curated* effects alone, without the fake narrator's own
/// canned exp/resource deltas (allowed by the contract, but noise here).
class _QuietNarrator implements NarratorPort {
  const _QuietNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    return const NarratorResponse(
      narration: 'Narración de prueba.',
      suggestedChoices: [],
      stateDeltas: [],
      imagePrompt: '',
      tone: '',
    );
  }
}

const _origin = CharacterOrigin(
  id: 'origen_test',
  displayName: 'Origen de prueba',
  baseAttributes: {'cuerpo': 3},
  tagId: 'tag_test',
);

const _vow = Vow(id: 'vow_test', text: 'Un juramento de prueba.');

final _graph = StoryGraph(
  startNodeId: 'anchor',
  nodes: {
    'anchor': const FixedAnchorNode(
      id: 'anchor',
      narration: 'Estás ante la puerta.',
      choices: [
        StoryChoice(
          label: 'Forzarla',
          targetNodeId: 'corridor',
          checkAttribute: 'cuerpo',
          checkDifficulty: 12,
          onSuccess: ChoiceOutcome(
            effects: [StateDelta(type: StateDeltaType.exp, key: 'exp', value: 1)],
          ),
          onFailure: ChoiceOutcome(
            targetNodeId: 'anchor',
            effects: [StateDelta(type: StateDeltaType.resource, key: 'vitality', value: -1)],
          ),
        ),
      ],
    ),
    'corridor': const BoundedCorridorNode(
      id: 'corridor',
      goal: 'Cruzar el puente.',
      turnBudget: 2,
      fallbackExitNodeId: 'hub',
      choices: [
        StoryChoice(label: 'Cruzar directo', targetNodeId: 'hub'),
      ],
    ),
    'hub': const StateHubNode(
      id: 'hub',
      activities: [
        HubActivity(
          id: 'descansar',
          label: 'Descansar',
          // A resource with no declared formula (unlike vitality), so the
          // assertion below isn't affected by formula-based capping.
          effects: [StateDelta(type: StateDeltaType.resource, key: 'stamina', value: 5)],
        ),
      ],
      exits: [
        StoryChoice(label: 'Salir', targetNodeId: 'conflict'),
      ],
    ),
    'conflict': const FixedAnchorNode(
      id: 'conflict',
      narration: 'El Coro te rodea.',
      extendedConflict: ExtendedConflict(successesRequired: 2, failuresAllowed: 2),
      choices: [
        StoryChoice(
          label: 'Contener',
          targetNodeId: 'end',
          checkAttribute: 'cuerpo',
          checkDifficulty: 12,
        ),
      ],
    ),
    'end': const FixedAnchorNode(id: 'end', narration: 'Fin.'),
  },
);

final _world = World(
  slug: 'test_curado',
  name: 'Mundo de prueba',
  theme: 'test',
  tone: 'neutro',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 99, // deliberately absurd, to prove choices never use it
  criticalMargin: 5,
  primaryAttribute: 'cuerpo',
  attributeKeys: const ['cuerpo', 'espiritu'],
  origins: const [_origin],
  vows: const [_vow],
  resourceFormulas: const {'vitality': ResourceFormula(base: 10)},
  storyGraph: _graph,
  startingCharacter: const Character(
    name: 'Placeholder',
    level: 1,
    exp: 0,
    attributes: {'cuerpo': 1, 'espiritu': 1},
    resources: {'vitality': 10},
  ),
  seedNarration: '',
  seedChoices: const [],
);

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => _world;
}

GameController _controllerWith(Dice dice) => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const _QuietNarrator(),
      dice: dice,
    );

void main() {
  group('GameController — chargen', () {
    test('builds the starting character from CreateCharacterInput via the origin', () async {
      final controller = _controllerWith(const FixedDice(10));
      await controller.start(
        'test_curado',
        chargenInput: const CreateCharacterInput(
          name: 'Protagonista',
          originId: 'origen_test',
          freeAttributePoint: 'espiritu',
          vowId: 'vow_test',
        ),
      );

      expect(controller.character!.name, 'Protagonista');
      expect(controller.character!.attribute('cuerpo'), 3);
      expect(controller.character!.attribute('espiritu'), 2); // 1 + free point
      expect(controller.character!.originId, 'origen_test');
      expect(controller.currentNode, isA<FixedAnchorNode>());
    });

    test('without a chargenInput, falls back to world.startingCharacter', () async {
      final controller = _controllerWith(const FixedDice(10));
      await controller.start('test_curado');
      expect(controller.character!.name, 'Placeholder');
    });
  });

  group('GameController — checked story choices', () {
    test('resolves against the choice\'s own attribute/difficulty, not world.defaultDifficulty', () async {
      // cuerpo 3 + roll 10 = 13 >= choice DC 12 (would fail against the
      // world's absurd defaultDifficulty of 99).
      final controller = _controllerWith(const FixedDice(10));
      await controller.start(
        'test_curado',
        chargenInput: const CreateCharacterInput(
          name: 'x',
          originId: 'origen_test',
          freeAttributePoint: 'espiritu',
          vowId: 'vow_test',
        ),
      );

      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );

      expect(controller.error, isNull);
      expect(controller.lastResolution!.isSuccess, isTrue);
      expect(controller.lastResolution!.difficulty, 12);
      expect(controller.character!.exp, 1);
      expect(controller.currentNode!.id, 'corridor');
    });

    test('a failed check can redirect back to a different target node', () async {
      final controller = _controllerWith(const FixedDice(1));
      await controller.start(
        'test_curado',
        chargenInput: const CreateCharacterInput(
          name: 'x',
          originId: 'origen_test',
          freeAttributePoint: 'espiritu',
          vowId: 'vow_test',
        ),
      );

      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );

      expect(controller.lastResolution!.isSuccess, isFalse);
      expect(controller.character!.resource('vitality'), 9);
      expect(controller.currentNode!.id, 'anchor');
    });
  });

  group('GameController — hub activities', () {
    test('applies effects without advancing currentNodeId', () async {
      final controller = _controllerWith(const FixedDice(20));
      await controller.start(
        'test_curado',
        chargenInput: const CreateCharacterInput(
          name: 'x',
          originId: 'origen_test',
          freeAttributePoint: 'espiritu',
          vowId: 'vow_test',
        ),
      );
      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      ); // -> corridor
      await controller.chooseStoryChoice(
        (controller.currentNode as BoundedCorridorNode).choices.single,
      ); // -> hub

      expect(controller.currentNode!.id, 'hub');
      final before = controller.character!.resource('stamina');

      await controller.chooseHubActivity(
        (controller.currentNode as StateHubNode).activities.single,
      );

      expect(controller.currentNode!.id, 'hub');
      expect(controller.character!.resource('stamina'), before + 5);
    });
  });

  group('GameController — bounded corridor turn budget', () {
    test('forces the fallback exit once free-text turns exhaust the budget', () async {
      final controller = _controllerWith(const FixedDice(20));
      await controller.start(
        'test_curado',
        chargenInput: const CreateCharacterInput(
          name: 'x',
          originId: 'origen_test',
          freeAttributePoint: 'espiritu',
          vowId: 'vow_test',
        ),
      );
      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      ); // -> corridor (turn_budget: 2)

      expect(controller.currentNode!.id, 'corridor');

      await controller.choose('Miro alrededor buscando otra salida');
      expect(controller.currentNode!.id, 'corridor');

      await controller.choose('Insisto explorando el lugar');
      expect(controller.currentNode!.id, 'hub');
    });
  });

  group('GameController — extended conflict', () {
    test('stays on the same node until the conflict is decided, then advances', () async {
      final controller = _controllerWith(const FixedDice(20));
      await controller.start(
        'test_curado',
        chargenInput: const CreateCharacterInput(
          name: 'x',
          originId: 'origen_test',
          freeAttributePoint: 'espiritu',
          vowId: 'vow_test',
        ),
      );
      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      ); // -> corridor
      await controller.chooseStoryChoice(
        (controller.currentNode as BoundedCorridorNode).choices.single,
      ); // -> hub
      await controller.chooseStoryChoice(
        (controller.currentNode as StateHubNode).exits.single,
      ); // -> conflict

      expect(controller.currentNode!.id, 'conflict');

      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );
      // Only 1 of 2 required successes so far — still the same node.
      expect(controller.currentNode!.id, 'conflict');

      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );
      // 2nd success reached — the conflict resolves and the scene advances.
      expect(controller.currentNode!.id, 'end');
    });
  });
}
