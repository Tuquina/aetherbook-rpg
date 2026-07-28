import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/my_stories_screen.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => World(
        slug: slug,
        name: slug == 'isekai' ? 'Isekai' : 'Xianxia',
        theme: slug,
        tone: 'neutro',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'voluntad',
        startingCharacter: const Character(
            name: 'Protagonista', level: 1, exp: 0, attributes: {}, resources: {}),
        seedNarration: '',
        seedChoices: const [],
      );
}

class _FakeGameStateRepository implements GameStateRepositoryPort {
  _FakeGameStateRepository(this.entries);

  final List<SessionLibraryEntry> entries;
  final List<String> startedSessionIds = [];

  @override
  Future<List<SessionLibraryEntry>> storyLibrary() async => entries;

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => null;
  @override
  Future<GameSession?> loadSession(String sessionId) async => null;
  @override
  Future<List<GameSessionSummary>> listActiveSessions(List<String> worldSlugs) async => const [];
  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
    String? title,
  }) async =>
      GameSession(id: 'x', worldSlug: worldSlug, character: character);
  @override
  Future<void> saveCharacter(String sessionId, Character character) async {}
  @override
  Future<void> appendTurn({
    required String sessionId,
    required int turnIndex,
    required playerAction,
    required resolution,
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
  Future<String?> loadLatestMemoryDigest(String sessionId) async => null;
  @override
  Future<void> saveMemoryDigest({
    required String sessionId,
    required int upToTurn,
    required String summaryText,
  }) async {}
  @override
  Future<List<SessionReadingStat>> readingStats() async => const [];
}

Future<void> _pumpMyStories(WidgetTester tester, List<SessionLibraryEntry> entries,
    {Size size = const Size(390, 2000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = GameController(
    worldRepository: _FakeWorldRepository(),
    narrator: const FakeNarratorAdapter(latency: Duration.zero),
    persistence: _FakeGameStateRepository(entries),
  );
  final worlds = [
    await controller.loadWorldInfo('isekai'),
    await controller.loadWorldInfo('xianxia'),
  ];
  await tester.pumpWidget(MaterialApp(
    home: MyStoriesScreen(controller: controller, catalogWorlds: worlds),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('MyStoriesScreen', () {
    testWidgets('"Todas" lists active/completed sessions plus unstarted worlds, never abandoned',
        (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fernando',
          turnCount: 4,
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        SessionLibraryEntry(
          sessionId: 's2',
          worldSlug: 'isekai',
          status: 'abandoned',
          characterName: 'Otro',
          turnCount: 1,
          updatedAt: DateTime.now(),
        ),
      ]);

      expect(find.text('Fernando · turno 4 · hace 2 d'), findsOneWidget);
      expect(find.text('Otro · turno 1 · hace 0 d'), findsNothing);
      // xianxia has no session -> shows as "sin empezar" (that text also
      // matches the "Sin empezar" filter tab's own label, hence 2).
      expect(find.text('Sin empezar'), findsNWidgets(2));
      expect(find.text('Xianxia'), findsOneWidget);
    });

    testWidgets('"En curso" tab only shows active sessions', (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'completed',
          characterName: 'Fernando',
          turnCount: 40,
          updatedAt: DateTime.now(),
        ),
      ]);

      // .first: the tab label itself always says "En curso" is right next to
      // a "Sin empezar" tab label match too before the tap.
      await tester.tap(find.text('En curso').first);
      await tester.pump();

      expect(find.textContaining('terminada'), findsNothing);
      // The only entry is completed (not active), and "En curso" never shows
      // unstarted worlds (that's "Sin empezar"'s job) -> empty state, so the
      // only remaining "Sin empezar" match left is the filter tab itself.
      expect(find.text('Sin empezar'), findsOneWidget);
      expect(find.text('Todavía no hay historias acá.'), findsOneWidget);
    });

    testWidgets('"Sin empezar" tab only shows worlds with no session', (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fernando',
          turnCount: 4,
          updatedAt: DateTime.now(),
        ),
      ]);

      // .first: the tab's own label collides with xianxia's unstarted-card
      // subtitle, both literally "Sin empezar", in the default "Todas" view.
      await tester.tap(find.text('Sin empezar').first);
      await tester.pump();

      expect(find.text('Fernando · turno 4 · hace 0 h'), findsNothing);
      expect(find.text('Xianxia'), findsOneWidget);
      expect(find.text('Isekai'), findsNothing);
    });

    testWidgets('shows a completed session with "terminada", not a turn count', (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'completed',
          characterName: 'Fernando',
          turnCount: 46,
          updatedAt: DateTime.now(),
        ),
      ]);

      expect(find.text('Fernando · terminada'), findsOneWidget);
    });

    testWidgets('shows the total tomo count in the header', (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fernando',
          turnCount: 4,
          updatedAt: DateTime.now(),
        ),
      ]);

      // isekai (started) + xianxia (sin empezar) = 2 rows total.
      expect(find.text('2 tomos'), findsOneWidget);
    });

    testWidgets('an active session shows a general-advancement progress bar', (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fernando',
          turnCount: 15,
          updatedAt: DateTime.now(),
        ),
      ]);

      final fsb = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
      expect(fsb.widthFactor, closeTo(15 / 30, 0.001));
    });

    testWidgets('an unstarted world shows no progress bar', (tester) async {
      await _pumpMyStories(tester, []);
      expect(find.byType(FractionallySizedBox), findsNothing);
    });
  });

  group('MyStoriesScreen responsive layout (V2 §2b/§4d, Stage V)', () {
    testWidgets('below tablet width: a plain ListView, chip labels carry no count',
        (tester) async {
      await _pumpMyStories(tester, [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fernando',
          turnCount: 4,
          updatedAt: DateTime.now(),
        ),
      ]);

      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(find.text('Todas'), findsOneWidget); // no "Todas · N"
    });

    testWidgets('at/above tablet width: a GridView, chips carry their own count',
        (tester) async {
      await _pumpMyStories(
        tester,
        [
          SessionLibraryEntry(
            sessionId: 's1',
            worldSlug: 'isekai',
            status: 'active',
            characterName: 'Fernando',
            turnCount: 4,
            updatedAt: DateTime.now(),
          ),
        ],
        size: const Size(900, 2000),
      );

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      // isekai (active) + xianxia (sin empezar) = 2 total, 1 active, 1 unstarted.
      expect(find.text('Todas · 2'), findsOneWidget);
      expect(find.text('En curso · 1'), findsOneWidget);
      expect(find.text('Sin empezar · 1'), findsOneWidget);
    });
  });
}
