import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/world_select_screen.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every slug [WorldSelectScreen] tries to load resolves to a distinct,
/// `storyGraph`-less world named after its own slug. With no story graph
/// declared, every one of them buckets into `StoryModule.aiNarrator` ("Crea
/// tu propia historia") — the only module where several sessions can share
/// one world slug (CLAUDE.md Fase 2), which is exactly where "resume the
/// story I tapped, not whichever one happens to be newest" actually matters.
class _EchoWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => World(
        slug: slug,
        name: 'Mundo $slug',
        theme: slug,
        tone: 'épico',
        systemPrompt: '',
        imageStyleSuffix: 'arte',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'espiritu',
        startingCharacter: const Character(
          name: 'Protagonista',
          level: 1,
          exp: 0,
          attributes: {'espiritu': 2},
          resources: {'qi': 10},
        ),
        seedNarration: 'Comienza una historia nueva.',
        seedChoices: const ['Avanzar'],
      );
}

/// In-memory fake of the persistence port (same shape as the one in
/// game_controller_persistence_test.dart) — answers [loadSession] and
/// [listActiveSessions] from data the test seeds directly, so no Supabase or
/// asset bundle is ever touched.
class _FakeGameStateRepository implements GameStateRepositoryPort {
  GameSession? seeded;
  final Map<String, GameSession> sessionsById = {};
  List<GameSessionSummary> summariesToReturn = const [];
  int createSessionCalls = 0;

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => seeded;

  @override
  Future<GameSession?> loadSession(String sessionId) async =>
      sessionsById[sessionId];

  @override
  Future<List<GameSessionSummary>> listActiveSessions(
          List<String> worldSlugs) async =>
      summariesToReturn;

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
    String? title,
  }) async {
    createSessionCalls++;
    return GameSession(id: 'new-session', worldSlug: worldSlug, character: character);
  }

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
  Future<void> saveTurnImage({
    required String sessionId,
    required int turnIndex,
    required String imageUrl,
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
  }) async {}

  @override
  Future<void> abandonSession(String sessionId) async {}

  @override
  Future<void> completeSession(String sessionId) async {}

  @override
  Future<List<SessionReadingStat>> readingStats() async => const [];
}

void main() {
  testWidgets(
      'tapping a saved story card resumes that exact session, not the '
      'latest one, through real screen navigation (WorldSelectScreen -> '
      'CreateStoryScreen -> GameScreen)', (tester) async {
    // Two sessions share the same freeform world slug. `seeded` answers
    // loadLatestSession() and is deliberately the *other* session, so this
    // test fails loudly if resuming a tapped card ever falls back to "the
    // latest" instead of the exact session id the player chose — the same
    // class of bug widget_test.dart's third case guards against for
    // WorldSelectScreen's own fast path, but exercised here through actual
    // taps instead of the GameController API directly.
    final persistence = _FakeGameStateRepository()
      ..seeded = GameSession(
        id: 'latest-story',
        worldSlug: 'isekai',
        character: const Character(
          name: 'Última',
          level: 1,
          exp: 0,
          attributes: {'espiritu': 2},
          resources: {'qi': 10},
        ),
      )
      ..sessionsById['older-story'] = GameSession(
        id: 'older-story',
        worldSlug: 'isekai',
        character: const Character(
          name: 'Vieja',
          level: 4,
          exp: 0,
          attributes: {'espiritu': 2},
          resources: {'qi': 10},
        ),
        turns: const [
          Turn(
            index: 0,
            playerAction: 'Meditar',
            narration: 'La historia vieja sigue acá.',
            tone: 'sereno',
            suggestedChoices: ['Seguir'],
          ),
        ],
      )
      ..summariesToReturn = [
        GameSessionSummary(
          id: 'older-story',
          worldSlug: 'isekai',
          characterName: 'Vieja',
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        GameSessionSummary(
          id: 'latest-story',
          worldSlug: 'isekai',
          characterName: 'Última',
          updatedAt: DateTime.now(),
        ),
      ];

    final controller = GameController(
      worldRepository: _EchoWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      persistence: persistence,
      dice: const FixedDice(10),
    );

    await tester
        .pumpWidget(MaterialApp(home: WorldSelectScreen(controller: controller)));
    await tester.pump(); // resolve the 8 loadWorldInfo() calls behind the module list

    // Open "Crea tu propia historia" — the only module where several
    // sessions can share one world slug.
    await tester.tap(find.text('Crea tu propia historia'));
    await tester.pump(); // start the push transition
    await tester.pump(const Duration(milliseconds: 500)); // finish it + resolve listCreatedStories()

    // Both saved stories are listed...
    expect(find.text('Vieja'), findsOneWidget);
    expect(find.text('Última'), findsOneWidget);

    // ...tap the OLDER one specifically.
    await tester.tap(find.text('Vieja'));
    await tester.pump(); // kicks off controller.start(..., sessionId: 'older-story')
    await tester.pump(const Duration(milliseconds: 500)); // pushReplacement + GameScreen settle

    // The controller loaded the exact tapped session — not
    // loadLatestSession()'s answer, and not a freshly created one either.
    expect(persistence.createSessionCalls, 0);
    expect(controller.character!.name, 'Vieja');
    expect(find.textContaining('La historia vieja sigue acá.'), findsOneWidget);
    expect(find.textContaining('Última'), findsNothing);
  });
}
