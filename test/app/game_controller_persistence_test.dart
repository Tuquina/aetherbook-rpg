import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
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
  seedNarration: 'Comienza el sendero de piedra.',
  seedChoices: ['Meditar', 'Explorar'],
);

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => _world;
}

/// In-memory fake of the persistence port — records every call so tests can
/// assert on it, without touching Supabase.
class _FakeGameStateRepository implements GameStateRepositoryPort {
  GameSession? seeded;
  final List<String> savedCharacterCalls = [];
  final List<int> appendedTurnIndexes = [];
  int createSessionCalls = 0;

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => seeded;

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
  }) async {
    createSessionCalls++;
    return GameSession(id: 'new-session', worldSlug: worldSlug, character: character);
  }

  @override
  Future<void> saveCharacter(String sessionId, Character character) async {
    savedCharacterCalls.add(sessionId);
  }

  @override
  Future<void> appendTurn({
    required String sessionId,
    required int turnIndex,
    required String playerAction,
    required ActionResolution? resolution,
    required String narration,
    required String tone,
    required List<String> suggestedChoices,
  }) async {
    appendedTurnIndexes.add(turnIndex);
  }
}

void main() {
  group('GameController with persistence', () {
    test('creates a new session and shows the seed when none exists', () async {
      final persistence = _FakeGameStateRepository();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        persistence: persistence,
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');

      expect(persistence.createSessionCalls, 1);
      expect(controller.narration, contains('sendero de piedra'));
      expect(controller.choices, _world.seedChoices);
    });

    test('resumes from the last turn when a session already exists', () async {
      final persistence = _FakeGameStateRepository()
        ..seeded = GameSession(
          id: 'existing-session',
          worldSlug: 'xianxia',
          character: _character.copyWith(level: 2, exp: 50),
          turns: const [
            Turn(
              index: 0,
              playerAction: 'Meditar',
              narration: 'Ya meditaste una vez.',
              tone: 'sereno',
              suggestedChoices: ['Seguir meditando', 'Levantarte'],
            ),
          ],
        );

      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        persistence: persistence,
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');

      expect(persistence.createSessionCalls, 0);
      expect(controller.narration, 'Ya meditaste una vez.');
      expect(controller.choices, ['Seguir meditando', 'Levantarte']);
      expect(controller.character!.level, 2);
    });

    test('choose() persists the character and appends the turn', () async {
      final persistence = _FakeGameStateRepository();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        persistence: persistence,
        dice: const FixedDice(10), // 2 + 10 = 12 vs 12 -> success
      );

      await controller.start('xianxia');
      await controller.choose('Meditar');

      expect(persistence.savedCharacterCalls, ['new-session']);
      expect(persistence.appendedTurnIndexes, [0]);
    });

    test('without persistence, behaves exactly like Fase 0 (in-memory only)', () async {
      final controller = GameController(
        worldRepository: _FakeWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(10),
      );

      await controller.start('xianxia');
      expect(controller.narration, contains('sendero de piedra'));

      await controller.choose('Meditar');
      expect(controller.error, isNull);
    });
  });
}
