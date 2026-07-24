// Covers the plan's central engine extension: a world declaring
// `ai_runtime_required: false` must never call NarratorPort, must render
// each outcome's own resultText (interpolated), must ignore free-text input
// when `allowFreeText == false`, and must persist its graph position on
// every advance — none of which the pre-existing hybrid (xianxia_lianshu)
// coverage exercises, since that world always keeps `aiRuntimeRequired: true`.
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails the test if it's ever invoked — proves a `aiRuntimeRequired: false`
/// world makes zero AI calls, rather than merely asserting the *output*
/// looks curated.
class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('NarratorPort.narrate must never be called for an AI-free world');
  }
}

final _graph = StoryGraph(
  startNodeId: 'p0',
  nodes: {
    'p0': const FixedAnchorNode(
      id: 'p0',
      narration: 'Damián despierta a las 03:12.',
      choices: [
        StoryChoice(
          label: 'Ayudar a Ramiro en la puerta norte',
          targetNodeId: 'p1_close',
          checkAttribute: 'cuerpo',
          checkDifficulty: 12,
          onSuccess: ChoiceOutcome(
            resultText: 'La puerta sigue cerrada. {{name}} respira.',
            effects: [StateDelta(type: StateDeltaType.flag, key: 'saved_north_gate', value: true)],
          ),
          onFailure: ChoiceOutcome(
            resultText: 'Los dientes cierran sobre la manga.',
            effects: [StateDelta(type: StateDeltaType.resource, key: 'health', value: -2)],
          ),
        ),
      ],
    ),
    'p1_close': const FixedAnchorNode(
      id: 'p1_close',
      narration: 'La Cámara cuenta: sesenta y tres vivos.',
      conditionalInserts: [
        ConditionalInsert(
          text: 'Ramiro asiente una vez, sin decir nada.',
        ),
      ],
    ),
  },
);

final _world = World(
  slug: 'curated_zombie_test',
  name: 'Historia de prueba sin IA',
  theme: 'test',
  tone: 'seco',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'cuerpo',
  storyGraph: _graph,
  startingCharacter: const Character(
    name: 'Damián',
    level: 1,
    exp: 0,
    attributes: {'cuerpo': 2},
    resources: {'health': 20},
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

class _RecordingPersistence implements GameStateRepositoryPort {
  final List<String?> savedGraphNodeIds = [];

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => null;

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
  }) async =>
      GameSession(id: 'session-1', worldSlug: worldSlug, character: character);

  @override
  Future<void> saveCharacter(String sessionId, Character character) async {}

  @override
  Future<void> appendTurn({
    required String sessionId,
    required int turnIndex,
    required String playerAction,
    required ActionResolution? resolution,
    required String narration,
    required String tone,
    required List<String> suggestedChoices,
  }) async {}

  @override
  Future<String?> loadLatestMemoryDigest(String sessionId) async => null;

  @override
  Future<void> saveMemoryDigest({
    required String sessionId,
    required int upToTurn,
    required String summaryText,
  }) async {}

  @override
  Future<void> saveGraphPosition({
    required String sessionId,
    String? currentNodeId,
    required int corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
  }) async {
    savedGraphNodeIds.add(currentNodeId);
  }

  @override
  Future<void> abandonSession(String sessionId) async {}
}

void main() {
  group('GameController — ai_runtime_required: false (curated, AI-free campaign)', () {
    test('never calls NarratorPort and narrates from the outcome\'s own resultText', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const _ForbiddenNarrator(),
        dice: const FixedDice(15), // 2 + 15 = 17 >= DC 12 -> success
      );

      await controller.start('curated_zombie_test');
      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );

      expect(controller.error, isNull);
      expect(controller.character!.flag('saved_north_gate'), isTrue);
      // resultText interpolated with the protagonist's name, plus the next
      // node's literal narration + conditional insert, concatenated — no AI
      // prose anywhere.
      expect(controller.narration, contains('La puerta sigue cerrada. Damián respira.'));
      expect(controller.narration, contains('La Cámara cuenta: sesenta y tres vivos.'));
      expect(controller.narration, contains('Ramiro asiente una vez, sin decir nada.'));
    });

    test('offers no AI-suggested choices — only the graph\'s own', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const _ForbiddenNarrator(),
        dice: const FixedDice(15),
      );
      await controller.start('curated_zombie_test');
      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );
      expect(controller.choices, isEmpty);
    });

    test('choose() (free text) is a no-op when allowFreeText is false', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const _ForbiddenNarrator(),
        dice: const FixedDice(15),
      );
      await controller.start('curated_zombie_test');
      final before = controller.narration;

      await controller.choose('Intento algo que no está en el menú');

      expect(controller.narration, before);
      expect(controller.error, isNull);
    });

    test('persists the new currentNodeId via saveGraphPosition on every advance', () async {
      final persistence = _RecordingPersistence();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const _ForbiddenNarrator(),
        persistence: persistence,
        dice: const FixedDice(15),
      );
      await controller.start('curated_zombie_test');
      await controller.chooseStoryChoice(
        (controller.currentNode as FixedAnchorNode).choices.single,
      );

      expect(persistence.savedGraphNodeIds, ['p1_close']);
    });
  });
}
