// The home dashboard's "Dejaste el tomo abierto" hero (V2 §8a/§8b) — rebuilt
// from a compact icon+text pill into a real hero (background image/quote/2
// buttons), plus its empty-state twin `_StartHero` shown when the account has
// no active session at all.
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/story_module_screen.dart';
import 'package:aetherbook/app/world_select_screen.dart';
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

  @override
  Future<List<SessionLibraryEntry>> storyLibrary() async => entries;

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => null;
  @override
  Future<GameSession?> loadSession(String sessionId) async => null; // "no existe" path
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
  Future<void> saveCharacterAvatar({
    required String sessionId,
    required String avatarUrl,
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

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<SessionLibraryEntry> entries,
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = GameController(
    worldRepository: _FakeWorldRepository(),
    narrator: const FakeNarratorAdapter(latency: Duration.zero),
    persistence: _FakeGameStateRepository(entries),
  );
  await tester.pumpWidget(MaterialApp(home: WorldSelectScreen(controller: controller)));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('_ContinueHero (active session)', () {
    testWidgets('shows the quote, both buttons and the relative-time meta line',
        (tester) async {
      await _pumpHome(tester, entries: [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fer',
          turnCount: 4,
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
          lastNarration: 'El metal retumbó en la estancia como una campana de alarma.',
        ),
      ]);

      expect(find.textContaining('«El metal retumbó'), findsOneWidget);
      expect(find.text('Retomar el turno 4'), findsOneWidget);
      expect(find.text('Empezar una historia nueva'), findsOneWidget);
      expect(find.textContaining('Isekai · hace 2 d'), findsOneWidget);
    });

    testWidgets('omits the quote block when there is no narration yet', (tester) async {
      await _pumpHome(tester, entries: [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fer',
          turnCount: 1,
          updatedAt: DateTime.now(),
        ),
      ]);

      expect(find.textContaining('«'), findsNothing);
      expect(find.text('Retomar el turno 1'), findsOneWidget);
    });

    testWidgets('"Empezar una historia nueva" opens the Historia completa module',
        (tester) async {
      await _pumpHome(tester, entries: [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fer',
          turnCount: 1,
          updatedAt: DateTime.now(),
        ),
      ]);

      await tester.tap(find.text('Empezar una historia nueva'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StoryModuleScreen), findsOneWidget);
      expect(find.text('Historias completas'), findsWidgets);
    });

    testWidgets('"Retomar el turno N" attempts to resume that exact session', (tester) async {
      await _pumpHome(tester, entries: [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          characterName: 'Fer',
          turnCount: 1,
          updatedAt: DateTime.now(),
        ),
      ]);

      await tester.tap(find.text('Retomar el turno 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The fake's loadSession always returns null -> GameController.start
      // surfaces its "no existe" error via a SnackBar instead of navigating,
      // which is enough to prove this button really tried to resume s1
      // (not silently a no-op).
      expect(find.textContaining('No se pudo cargar esa historia'), findsOneWidget);
    });
  });

  group('_StartHero (no active session)', () {
    testWidgets('shows the empty-state invitation instead of a continue hero',
        (tester) async {
      await _pumpHome(tester, entries: const []);

      expect(find.text('Todavía no abriste ningún tomo'), findsOneWidget);
      expect(find.text('Empezar una historia'), findsOneWidget);
      expect(find.textContaining('Retomar el turno'), findsNothing);
    });

    testWidgets('a completed-only library also shows the empty-state hero (nothing active)',
        (tester) async {
      await _pumpHome(tester, entries: [
        SessionLibraryEntry(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'completed',
          characterName: 'Fer',
          turnCount: 40,
          updatedAt: DateTime.now(),
        ),
      ]);

      expect(find.text('Todavía no abriste ningún tomo'), findsOneWidget);
    });

    testWidgets('"Empezar una historia" opens the Historia completa module', (tester) async {
      await _pumpHome(tester, entries: const []);

      await tester.tap(find.text('Empezar una historia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StoryModuleScreen), findsOneWidget);
      expect(find.text('Historias completas'), findsWidgets);
    });
  });
}
