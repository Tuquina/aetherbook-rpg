import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/create_character.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/character_origin.dart';
import 'package:aetherbook/core/world/vow.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [FakeNarratorAdapter] to record the last [NarratorRequest] it saw,
/// so a test can assert on wiring (like `isFreeform`) without needing the
/// real HTTP adapter.
class _CapturingNarrator implements NarratorPort {
  _CapturingNarrator(this._delegate);

  final NarratorPort _delegate;
  NarratorRequest? lastRequest;

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) {
    lastRequest = request;
    return _delegate.narrate(request);
  }
}

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
  const _FakeWorldRepository([this.world = _world]);

  final World world;

  @override
  Future<World> loadWorld(String slug) async => world;
}

/// In-memory fake of the persistence port — records every call so tests can
/// assert on it, without touching Supabase.
class _FakeGameStateRepository implements GameStateRepositoryPort {
  GameSession? seeded;
  String? seededDigest;
  final List<String> savedCharacterCalls = [];
  final List<int> appendedTurnIndexes = [];
  final List<int> savedDigestUpToTurn = [];
  int createSessionCalls = 0;

  /// Sessions resolvable by id via [loadSession] — separate from [seeded]
  /// (which only ever answers [loadLatestSession]) since the two now model
  /// genuinely different lookups: "the newest session for this world" vs.
  /// "this exact session, whichever world it's for".
  final Map<String, GameSession> sessionsById = {};

  /// What [listActiveSessions] returns — set by a test, empty by default.
  List<GameSessionSummary> summariesToReturn = const [];
  final List<List<String>> listActiveSessionsCalls = [];

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => seeded;

  @override
  Future<GameSession?> loadSession(String sessionId) async => sessionsById[sessionId];

  @override
  Future<List<GameSessionSummary>> listActiveSessions(List<String> worldSlugs) async {
    listActiveSessionsCalls.add(worldSlugs);
    return summariesToReturn;
  }

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

  @override
  Future<String?> loadLatestMemoryDigest(String sessionId) async => seededDigest;

  @override
  Future<void> saveMemoryDigest({
    required String sessionId,
    required int upToTurn,
    required String summaryText,
  }) async {
    savedDigestUpToTurn.add(upToTurn);
  }

  final List<String?> savedGraphPositionNodeIds = [];

  @override
  Future<void> saveGraphPosition({
    required String sessionId,
    String? currentNodeId,
    required int corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
  }) async {
    savedGraphPositionNodeIds.add(currentNodeId);
  }

  final List<String> abandonedSessionIds = [];

  @override
  Future<void> abandonSession(String sessionId) async {
    abandonedSessionIds.add(sessionId);
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

    test('forceNew: true abandons an existing session and starts a clean one '
        '("reiniciar historia")', () async {
      final persistence = _FakeGameStateRepository()
        ..seeded = GameSession(
          id: 'existing-session',
          worldSlug: 'xianxia',
          character: _character.copyWith(level: 5, exp: 900),
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

      await controller.start('xianxia', forceNew: true);

      expect(persistence.abandonedSessionIds, ['existing-session']);
      expect(persistence.createSessionCalls, 1);
      expect(controller.narration, contains('sendero de piedra'));
      expect(controller.choices, _world.seedChoices);
      expect(controller.character!.level, 1);
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

    group('hasPersistedSession', () {
      test('true when a session already exists for that world', () async {
        final persistence = _FakeGameStateRepository()
          ..seeded = GameSession(
            id: 'existing-session',
            worldSlug: 'xianxia',
            character: _character,
          );
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: persistence,
          dice: const FixedDice(10),
        );

        expect(await controller.hasPersistedSession('xianxia'), isTrue);
      });

      test('false when no session exists yet for that world', () async {
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: _FakeGameStateRepository(),
          dice: const FixedDice(10),
        );

        expect(await controller.hasPersistedSession('xianxia'), isFalse);
      });

      test('false without persistence configured (Fase 0 in-memory mode)', () async {
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        expect(await controller.hasPersistedSession('xianxia'), isFalse);
      });
    });

    group('several stories per world (Fase 2 "creá tu propia historia")', () {
      test('alwaysCreateNew: true creates a new session without touching an existing one',
          () async {
        final persistence = _FakeGameStateRepository()
          ..seeded = GameSession(
            id: 'older-story',
            worldSlug: 'xianxia',
            character: _character.copyWith(level: 3, exp: 200),
          );
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: persistence,
          dice: const FixedDice(10),
        );

        await controller.start('xianxia', alwaysCreateNew: true);

        expect(persistence.createSessionCalls, 1);
        expect(persistence.abandonedSessionIds, isEmpty,
            reason: 'the older story must survive — several can coexist');
        expect(controller.narration, contains('sendero de piedra'));
      });

      test('sessionId resumes that exact session, not the latest one', () async {
        final persistence = _FakeGameStateRepository()
          ..seeded = GameSession(
            id: 'latest-story',
            worldSlug: 'xianxia',
            character: _character.copyWith(level: 1, name: 'Última'),
          )
          ..sessionsById['older-story'] = GameSession(
            id: 'older-story',
            worldSlug: 'xianxia',
            character: _character.copyWith(level: 4, name: 'Vieja'),
            turns: const [
              Turn(
                index: 0,
                playerAction: 'Meditar',
                narration: 'La historia vieja sigue acá.',
                tone: 'sereno',
                suggestedChoices: ['Seguir'],
              ),
            ],
          );

        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: persistence,
          dice: const FixedDice(10),
        );

        await controller.start('xianxia', sessionId: 'older-story');

        expect(persistence.createSessionCalls, 0);
        expect(controller.character!.name, 'Vieja');
        expect(controller.narration, 'La historia vieja sigue acá.');
      });

      test('an unknown sessionId sets an error instead of creating a new story',
          () async {
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: _FakeGameStateRepository(),
          dice: const FixedDice(10),
        );

        await controller.start('xianxia', sessionId: 'does-not-exist');

        expect(controller.error, isNotNull);
        expect(controller.isReady, isFalse);
      });

      test('a freeform world\'s opening narration is interpolated with the '
          'chosen character name', () async {
        const worldWithGreeting = World(
          slug: 'cyberpunk',
          name: 'Cyberpunk',
          theme: 'cyberpunk',
          tone: 'oscuro',
          systemPrompt: '',
          imageStyleSuffix: '',
          defaultDifficulty: 12,
          criticalMargin: 5,
          primaryAttribute: 'tecnica',
          startingCharacter: _character,
          seedNarration: '{{name}}: la ciudad no duerme.',
          seedChoices: ['Salir'],
        );
        final controller = GameController(
          worldRepository: const _FakeWorldRepository(worldWithGreeting),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        // No chargenInput needed — this world has no origins to pick from,
        // so start() falls back to `world.startingCharacter` (name
        // "Discípulo", same as every other test in this file's `_character`
        // fixture), which is exactly enough to prove the seed narration gets
        // interpolated against whichever character actually starts the game.
        await controller.start('cyberpunk');

        expect(controller.narration, 'Discípulo: la ciudad no duerme.');
      });

      test("a freeform world's opening scene uses the chosen origin's own "
          'seed content, not the generic world-level one', () async {
        const worldWithOrigins = World(
          slug: 'cyberpunk',
          name: 'Cyberpunk',
          theme: 'cyberpunk',
          tone: 'oscuro',
          systemPrompt: '',
          imageStyleSuffix: '',
          defaultDifficulty: 12,
          criticalMargin: 5,
          primaryAttribute: 'tecnica',
          startingCharacter: _character,
          origins: [
            CharacterOrigin(
              id: 'combate',
              displayName: 'Transportado en combate',
              baseAttributes: {'reflejos': 3},
              tagId: 'reflejos_de_otro_mundo',
              seedNarration: '{{name}} esquiva el primer golpe por instinto.',
              seedChoices: ['Pelear', 'Huir', 'Gritar'],
            ),
            CharacterOrigin(
              id: 'error',
              displayName: 'Convocado por error',
              baseAttributes: {'ingenio': 3},
              tagId: 'convocado_sin_querer',
            ),
          ],
          vows: [Vow(id: 'v1', text: 'Un juramento cualquiera')],
          seedNarration: 'Texto genérico del mundo, no debería aparecer acá.',
          seedChoices: ['Genérica 1', 'Genérica 2', 'Genérica 3'],
        );
        final controller = GameController(
          worldRepository: const _FakeWorldRepository(worldWithOrigins),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        await controller.start(
          'cyberpunk',
          chargenInput: const CreateCharacterInput(
            name: 'Vex',
            originId: 'combate',
            vowId: 'v1',
          ),
        );

        expect(controller.error, isNull);
        expect(controller.narration, 'Vex esquiva el primer golpe por instinto.');
        expect(controller.choices, ['Pelear', 'Huir', 'Gritar']);
      });

      test("an origin with no seed content of its own falls back to the "
          "world's generic seed narration/choices", () async {
        const worldWithOrigins = World(
          slug: 'cyberpunk',
          name: 'Cyberpunk',
          theme: 'cyberpunk',
          tone: 'oscuro',
          systemPrompt: '',
          imageStyleSuffix: '',
          defaultDifficulty: 12,
          criticalMargin: 5,
          primaryAttribute: 'tecnica',
          startingCharacter: _character,
          origins: [
            CharacterOrigin(
              id: 'error',
              displayName: 'Convocado por error',
              baseAttributes: {'ingenio': 3},
              tagId: 'convocado_sin_querer',
            ),
          ],
          vows: [Vow(id: 'v1', text: 'Un juramento cualquiera')],
          seedNarration: '{{name}}, texto genérico del mundo.',
          seedChoices: ['Genérica 1', 'Genérica 2', 'Genérica 3'],
        );
        final controller = GameController(
          worldRepository: const _FakeWorldRepository(worldWithOrigins),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        await controller.start(
          'cyberpunk',
          chargenInput: const CreateCharacterInput(
            name: 'Vex',
            originId: 'error',
            vowId: 'v1',
          ),
        );

        expect(controller.narration, 'Vex, texto genérico del mundo.');
        expect(controller.choices, ['Genérica 1', 'Genérica 2', 'Genérica 3']);
      });

      test('the personal item, when the player filled one in, gets appended '
          'as a hook so it actually shows up in the story', () async {
        const worldWithHook = World(
          slug: 'cyberpunk',
          name: 'Cyberpunk',
          theme: 'cyberpunk',
          tone: 'oscuro',
          systemPrompt: '',
          imageStyleSuffix: '',
          defaultDifficulty: 12,
          criticalMargin: 5,
          primaryAttribute: 'tecnica',
          startingCharacter: _character,
          origins: [
            CharacterOrigin(
              id: 'x',
              displayName: 'Origen de prueba',
              baseAttributes: {'tecnica': 3},
              tagId: 'tag_x',
            ),
          ],
          vows: [Vow(id: 'x', text: 'Juramento de prueba')],
          seedNarration: 'Apertura genérica.',
          seedChoices: ['A', 'B', 'C'],
          personalItemSeedHook: 'Seguís llevando {{personalItem}} con vos.',
        );
        final controller = GameController(
          worldRepository: const _FakeWorldRepository(worldWithHook),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        await controller.start(
          'cyberpunk',
          chargenInput: const CreateCharacterInput(
            name: 'Vex',
            originId: 'x', // no origins declared -> originByIdOrNull is null
            vowId: 'x',
            personalItem: 'una foto arrugada',
          ),
        );

        expect(controller.narration,
            'Apertura genérica.\n\nSeguís llevando una foto arrugada con vos.');
      });

      test('no personal item means no hook paragraph gets appended', () async {
        const worldWithHook = World(
          slug: 'cyberpunk',
          name: 'Cyberpunk',
          theme: 'cyberpunk',
          tone: 'oscuro',
          systemPrompt: '',
          imageStyleSuffix: '',
          defaultDifficulty: 12,
          criticalMargin: 5,
          primaryAttribute: 'tecnica',
          startingCharacter: _character,
          origins: [
            CharacterOrigin(
              id: 'x',
              displayName: 'Origen de prueba',
              baseAttributes: {'tecnica': 3},
              tagId: 'tag_x',
            ),
          ],
          vows: [Vow(id: 'x', text: 'Juramento de prueba')],
          seedNarration: 'Apertura genérica.',
          seedChoices: ['A', 'B', 'C'],
          personalItemSeedHook: 'Seguís llevando {{personalItem}} con vos.',
        );
        final controller = GameController(
          worldRepository: const _FakeWorldRepository(worldWithHook),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        await controller.start(
          'cyberpunk',
          chargenInput: const CreateCharacterInput(
            name: 'Vex',
            originId: 'x',
            vowId: 'x',
          ),
        );

        expect(controller.narration, 'Apertura genérica.');
      });

      test('listCreatedStories delegates to persistence.listActiveSessions', () async {
        final expected = [
          GameSessionSummary(
            id: 's1',
            worldSlug: 'cyberpunk',
            characterName: 'Vex',
            updatedAt: DateTime(2026, 7, 24),
          ),
        ];
        final persistence = _FakeGameStateRepository()..summariesToReturn = expected;
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: persistence,
          dice: const FixedDice(10),
        );

        final result = await controller.listCreatedStories(['cyberpunk', 'isekai']);

        expect(result, expected);
        expect(persistence.listActiveSessionsCalls, [
          ['cyberpunk', 'isekai']
        ]);
      });

      test('listCreatedStories is empty without persistence configured', () async {
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        expect(await controller.listCreatedStories(['cyberpunk']), isEmpty);
      });

      test('choose() sends isFreeform: true to the narrator for a graph-less '
          'world', () async {
        final narrator =
            _CapturingNarrator(const FakeNarratorAdapter(latency: Duration.zero));
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: narrator,
          dice: const FixedDice(10),
        );

        await controller.start('xianxia');
        await controller.choose('Meditar');

        expect(narrator.lastRequest!.isFreeform, isTrue);
      });

      test('continueStory() plays a no-check turn: empty playerAction, null '
          'resolution, still persists', () async {
        final persistence = _FakeGameStateRepository();
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: persistence,
          dice: const FixedDice(10),
        );

        await controller.start('xianxia');
        await controller.continueStory();

        expect(controller.error, isNull);
        expect(controller.lastResolution, isNull);
        expect(persistence.savedCharacterCalls, ['new-session']);
        expect(persistence.appendedTurnIndexes, [0]);
      });

      test('continueStory() is a no-op for a curated (graph) world', () async {
        final graph = StoryGraph(
          startNodeId: 'p0',
          nodes: const {
            'p0': FixedAnchorNode(id: 'p0', narration: 'Comienzo curado.'),
          },
        );
        final curatedWorld = World(
          slug: 'curated_test',
          name: 'Historia curada de prueba',
          theme: 'test',
          tone: 'seco',
          systemPrompt: '',
          imageStyleSuffix: '',
          defaultDifficulty: 12,
          criticalMargin: 5,
          primaryAttribute: 'espiritu',
          storyGraph: graph,
          startingCharacter: _character,
          seedNarration: '',
          seedChoices: const [],
        );
        final controller = GameController(
          worldRepository: _FakeWorldRepository(curatedWorld),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          dice: const FixedDice(10),
        );

        await controller.start('curated_test');
        final narrationBefore = controller.narration;
        await controller.continueStory();

        expect(controller.narration, narrationBefore);
      });

      test('abandonStory delegates to persistence.abandonSession', () async {
        final persistence = _FakeGameStateRepository();
        final controller = GameController(
          worldRepository: _FakeWorldRepository(),
          narrator: const FakeNarratorAdapter(latency: Duration.zero),
          persistence: persistence,
          dice: const FixedDice(10),
        );

        await controller.abandonStory('some-story');

        expect(persistence.abandonedSessionIds, ['some-story']);
      });
    });
  });
}
