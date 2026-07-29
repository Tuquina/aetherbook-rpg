import 'package:aetherbook/app/editor/playtest/campaign_playtest_controller.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/ending_fallback.dart';
import 'package:aetherbook/core/narrative/epilogue_beat.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/hub_activity.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

World _world({String primaryAttribute = 'cultivo'}) => World(
      slug: 'test',
      name: 'Mundo de prueba',
      theme: 'test',
      tone: 'neutro',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: primaryAttribute,
      attributeKeys: const ['cultivo', 'ingenio'],
      startingCharacter: const Character(name: 'x', level: 1, exp: 0, attributes: {}, resources: {}),
      seedNarration: '',
      seedChoices: const [],
    );

void main() {
  group('CampaignPlaytestController.restart', () {
    test('seeds a fresh character with every world attribute at 2', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {'a': const FixedAnchorNode(id: 'a')});
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      expect(controller.character.attribute('cultivo'), 2);
      expect(controller.character.attribute('ingenio'), 2);
      expect(controller.currentNodeId, 'a');
      expect(controller.path, ['a']);
      expect(controller.isEnded, isFalse);
    });

    test('jumping to a specific node resets the path to just that node', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': const FixedAnchorNode(id: 'a'),
        'b': const FixedAnchorNode(id: 'b'),
      });
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      controller.restart('b');
      expect(controller.currentNodeId, 'b');
      expect(controller.path, ['b']);
    });
  });

  group('CampaignPlaytestController.chooseAction — unconditional', () {
    test('advances to the target and applies effects', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a', choices: [
          const StoryChoice(
            label: 'ir',
            targetNodeId: 'b',
            effects: [StateDelta(type: StateDeltaType.flag, key: 'moved', value: true)],
            resultText: 'Te vas.',
          ),
        ]),
        'b': const FixedAnchorNode(id: 'b'),
      });
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      controller.chooseAction(controller.availableActions.single);
      expect(controller.currentNodeId, 'b');
      expect(controller.path, ['a', 'b']);
      expect(controller.character.flag('moved'), isTrue);
      expect(controller.lastResultText, 'Te vas.');
    });

    test('a gated choice is excluded from availableActions until the flag is set', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a', choices: [
          const StoryChoice(label: 'oculta', targetNodeId: 'b', gate: FlagGate('unlocked')),
        ]),
        'b': const FixedAnchorNode(id: 'b'),
      });
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      expect(controller.availableActions, isEmpty);
      controller.toggleFlag('unlocked');
      expect(controller.availableActions, hasLength(1));
    });
  });

  group('CampaignPlaytestController.chooseAction — checked, forced dice', () {
    StoryGraph graph() => StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            const StoryChoice(
              label: 'forzar',
              targetNodeId: 'fallback',
              checkAttribute: 'cultivo',
              checkDifficulty: 15,
              onSuccess: ChoiceOutcome(targetNodeId: 'exito', resultText: 'bien'),
              onFailure: ChoiceOutcome(targetNodeId: 'fracaso', resultText: 'mal'),
            ),
          ]),
          'fallback': const FixedAnchorNode(id: 'fallback'),
          'exito': const FixedAnchorNode(id: 'exito'),
          'fracaso': const FixedAnchorNode(id: 'fracaso'),
        });

    test('forceSuccess always resolves onSuccess', () {
      final controller = CampaignPlaytestController(graph: graph(), world: _world(), nodeTitles: const {});
      controller.setDiceMode(PlaytestDiceMode.forceSuccess);
      controller.chooseAction(controller.availableActions.single);
      expect(controller.currentNodeId, 'exito');
      expect(controller.lastResultText, 'bien');
    });

    test('forceFailure always resolves onFailure', () {
      final controller = CampaignPlaytestController(graph: graph(), world: _world(), nodeTitles: const {});
      controller.setDiceMode(PlaytestDiceMode.forceFailure);
      controller.chooseAction(controller.availableActions.single);
      expect(controller.currentNodeId, 'fracaso');
      expect(controller.lastResultText, 'mal');
    });

    test('force20 resolves as a critical success, falling back to onSuccess', () {
      final controller = CampaignPlaytestController(graph: graph(), world: _world(), nodeTitles: const {});
      controller.setDiceMode(PlaytestDiceMode.force20);
      controller.chooseAction(controller.availableActions.single);
      expect(controller.currentNodeId, 'exito');
    });

    test('random mode uses a real ResolvePlayerAction roll via the injected Dice', () {
      final controller = CampaignPlaytestController(
        graph: graph(),
        world: _world(),
        nodeTitles: const {},
        dice: const FixedDice(1), // natural 1 -> always failure
      );
      controller.chooseAction(controller.availableActions.single);
      expect(controller.currentNodeId, 'fracaso');
      expect(controller.lastResolution, isNotNull);
      expect(controller.lastResolution!.isNatural1, isTrue);
    });
  });

  group('CampaignPlaytestController.chooseActivity', () {
    test('does not advance the graph, and marks a non-repeatable activity used', () {
      final graph = StoryGraph(startNodeId: 'hub', nodes: {
        'hub': const StateHubNode(
          activities: [HubActivity(id: 'a1', label: 'descansar', repeatable: false)],
          id: 'hub',
        ),
      });
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      final activity = controller.availableActivities.single;
      expect(controller.isActivityUsedUp(activity), isFalse);
      controller.chooseActivity(activity);
      expect(controller.currentNodeId, 'hub');
      expect(controller.isActivityUsedUp(activity), isTrue);
    });
  });

  group('CampaignPlaytestController.useFallbackExit', () {
    test('advances to the corridor\'s declared fallback', () {
      final graph = StoryGraph(startNodeId: 'corridor', nodes: {
        'corridor': const BoundedCorridorNode(
          id: 'corridor',
          goal: 'explorar',
          turnBudget: 3,
          fallbackExitNodeId: 'next',
        ),
        'next': const FixedAnchorNode(id: 'next'),
      });
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      controller.useFallbackExit();
      expect(controller.currentNodeId, 'next');
    });
  });

  group('CampaignPlaytestController.chooseEnding', () {
    test('on success, sets the ending flag and ends when no epilogue is declared', () {
      final graph = StoryGraph(startNodeId: 'end', nodes: {
        'end': const ResolutionNode(id: 'end', endings: [
          Ending(id: 'e1', visibleChoice: 'Terminar bien', baseDifficulty: 5),
        ]),
      });
      final controller = CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      controller.setDiceMode(PlaytestDiceMode.forceSuccess);
      controller.chooseEnding(controller.availableEndings.single);
      expect(controller.character.flag('ending_e1'), isTrue);
      expect(controller.isEnded, isTrue);
      expect(controller.epilogueBeats, isNull);
    });

    test('advances to and assembles the declared epilogue node instead of ending', () {
      final graph = StoryGraph(startNodeId: 'end', nodes: {
        'end': const ResolutionNode(
          id: 'end',
          endings: [Ending(id: 'e1', visibleChoice: 'Terminar')],
          epilogueNodeId: 'epilogue',
        ),
        'epilogue': const ResolutionNode(
          id: 'epilogue',
          epilogueBeats: [EpilogueBeat(movement: 'cierre', text: 'Todo termina.')],
        ),
      });
      final controller = CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      controller.setDiceMode(PlaytestDiceMode.forceSuccess);
      controller.chooseEnding(controller.availableEndings.single);
      expect(controller.currentNodeId, 'epilogue');
      expect(controller.isEnded, isFalse);
      expect(controller.epilogueBeats, ['Todo termina.']);
    });

    test('on failure, falls back to a different ending id when declared', () {
      final graph = StoryGraph(startNodeId: 'end', nodes: {
        'end': const ResolutionNode(id: 'end', endings: [
          Ending(
            id: 'e1',
            visibleChoice: 'Intentar el pacto',
            baseDifficulty: 30,
            onFailureFallbacks: [EndingFallback(gate: AlwaysGate(), endingId: 'e1_roto')],
          ),
        ]),
      });
      final controller = CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      controller.setDiceMode(PlaytestDiceMode.forceFailure);
      controller.chooseEnding(controller.availableEndings.single);
      expect(controller.character.flag('ending_e1_roto'), isTrue);
      expect(controller.character.flag('ending_e1'), isFalse);
    });
  });

  group('CampaignPlaytestController.flagKeys', () {
    test('lists every flag referenced anywhere in the graph', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a', choices: [
          const StoryChoice(label: 'x', targetNodeId: 'a', gate: FlagGate('saw_intro')),
        ]),
      });
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {});
      expect(controller.flagKeys, ['saw_intro']);
    });
  });

  group('CampaignPlaytestController.titleFor', () {
    test('falls back to the raw id when no title was authored', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {'a': const FixedAnchorNode(id: 'a')});
      final controller =
          CampaignPlaytestController(graph: graph, world: _world(), nodeTitles: const {'a': ''});
      expect(controller.titleFor('a'), 'a');
    });

    test('uses the authored title when set', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {'a': const FixedAnchorNode(id: 'a')});
      final controller = CampaignPlaytestController(
        graph: graph,
        world: _world(),
        nodeTitles: const {'a': 'El barco de ceniza'},
      );
      expect(controller.titleFor('a'), 'El barco de ceniza');
    });
  });
}
