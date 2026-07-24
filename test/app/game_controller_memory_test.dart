import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/memory_digest_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {'espiritu': 2},
  resources: {'qi': 10},
);

const _world = World(
  slug: 'xianxia',
  name: 'El Sendero del Qi',
  theme: 'xianxia',
  tone: 'épico',
  systemPrompt: '',
  imageStyleSuffix: 'arte xianxia',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'espiritu',
  startingCharacter: _character,
  seedNarration: 'Comienza el sendero.',
  seedChoices: ['Meditar'],
);

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => _world;
}

class _RecordingDigestPort implements MemoryDigestPort {
  final List<int> callTurnCounts = [];
  final List<String?> callPreviousDigests = [];
  int _calls = 0;

  @override
  Future<String> summarize({
    required List<Turn> turnsToSummarize,
    String? previousDigest,
  }) async {
    _calls++;
    callTurnCounts.add(turnsToSummarize.length);
    callPreviousDigests.add(previousDigest);
    return 'digest-$_calls';
  }
}

class _FakeGameStateRepository implements GameStateRepositoryPort {
  final List<int> savedDigestUpToTurn = [];
  final List<String> savedDigestSummaries = [];

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
  }) async {
    savedDigestUpToTurn.add(upToTurn);
    savedDigestSummaries.add(summaryText);
  }

  @override
  Future<void> saveGraphPosition({
    required String sessionId,
    String? currentNodeId,
    required int corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
  }) async {}

  @override
  Future<void> abandonSession(String sessionId) async {}
}

void main() {
  group('GameController three-level memory', () {
    test('does not summarize before digestEveryNTurns is reached', () async {
      final digest = _RecordingDigestPort();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        memoryDigest: digest,
        digestEveryNTurns: 2,
        dice: const FixedDice(10), // 2 + 10 = 12 vs 12 -> success
      );

      await controller.start('xianxia');
      await controller.choose('Meditar'); // turn 1 of 2

      expect(digest.callTurnCounts, isEmpty);
      expect(controller.memoryDigestText, isNull);
    });

    test('summarizes the last N turns once the threshold is hit', () async {
      final digest = _RecordingDigestPort();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        memoryDigest: digest,
        digestEveryNTurns: 2,
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');
      await controller.choose('Meditar'); // turn 1
      await controller.choose('Explorar'); // turn 2 -> triggers digest

      expect(digest.callTurnCounts, [2]);
      expect(digest.callPreviousDigests, [null]);
      expect(controller.memoryDigestText, 'digest-1');
    });

    test('continues the previous digest on the next regeneration', () async {
      final digest = _RecordingDigestPort();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        memoryDigest: digest,
        digestEveryNTurns: 2,
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');
      await controller.choose('Meditar'); // 1
      await controller.choose('Explorar'); // 2 -> digest-1
      await controller.choose('Meditar'); // 3
      await controller.choose('Explorar'); // 4 -> digest-2, continuing digest-1

      expect(digest.callTurnCounts, [2, 2]);
      expect(digest.callPreviousDigests, [null, 'digest-1']);
      expect(controller.memoryDigestText, 'digest-2');
    });

    test('persists each regenerated digest when persistence is configured', () async {
      final digest = _RecordingDigestPort();
      final persistence = _FakeGameStateRepository();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        persistence: persistence,
        memoryDigest: digest,
        digestEveryNTurns: 2,
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');
      await controller.choose('Meditar');
      await controller.choose('Explorar');

      expect(persistence.savedDigestUpToTurn, [2]);
      expect(persistence.savedDigestSummaries, ['digest-1']);
    });

    test('without a memoryDigest port, never calls summarize', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        digestEveryNTurns: 1,
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');
      await controller.choose('Meditar');

      expect(controller.memoryDigestText, isNull);
      expect(controller.error, isNull);
    });
  });
}
