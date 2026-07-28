import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/adapters/settings/fake_settings_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/profile_screen.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/vow.dart';
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
        vows: const [Vow(id: 'no_dejar_a_nadie', text: 'No dejo atrás a nadie.')],
      );
}

class _FakeGameStateRepository implements GameStateRepositoryPort {
  _FakeGameStateRepository(this.stats);

  final List<SessionReadingStat> stats;

  @override
  Future<List<SessionReadingStat>> readingStats() async => stats;

  @override
  Future<List<SessionLibraryEntry>> storyLibrary() async => const [];

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
    String? title,
  }) async =>
      GameSession(id: 'x', worldSlug: worldSlug, character: character);

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => null;
  @override
  Future<GameSession?> loadSession(String sessionId) async => null;
  @override
  Future<List<GameSessionSummary>> listActiveSessions(List<String> worldSlugs) async => const [];
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
}

GameController _controllerWith(List<SessionReadingStat> stats) => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      persistence: _FakeGameStateRepository(stats),
    );

Future<void> _pumpProfile(WidgetTester tester, GameController controller) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: ProfileScreen(
      controller: controller,
      authPort: FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev'),
      settingsPort: FakeSettingsAdapter(),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('ProfileScreen', () {
    testWidgets('shows real stats computed from readingStats, not placeholders',
        (tester) async {
      final controller = _controllerWith([
        const SessionReadingStat(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'completed',
          turnCount: 46,
        ),
        const SessionReadingStat(
          sessionId: 's2',
          worldSlug: 'xianxia',
          status: 'active',
          turnCount: 12,
        ),
        const SessionReadingStat(
          sessionId: 's3',
          worldSlug: 'isekai',
          status: 'abandoned',
          turnCount: 99,
        ),
      ]);
      await _pumpProfile(tester, controller);

      // 2 tomos (abandoned excluded), 58 turnos (46+12, abandoned excluded),
      // 1 terminada.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('58'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows a vow entry with the resolved vow text and outcome label',
        (tester) async {
      final controller = _controllerWith([
        const SessionReadingStat(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'completed',
          turnCount: 10,
          vowId: 'no_dejar_a_nadie',
          vowStatus: 'sostenido',
          title: 'La deuda de Aldren',
        ),
      ]);
      await _pumpProfile(tester, controller);

      expect(find.textContaining('No dejo atrás a nadie.'), findsOneWidget);
      expect(find.textContaining('Sostenido hasta el final'), findsOneWidget);
      expect(find.textContaining('La deuda de Aldren'), findsOneWidget);
    });

    testWidgets('shows "puesto a prueba" with the tested count for an unbroken, unfinished vow',
        (tester) async {
      final controller = _controllerWith([
        const SessionReadingStat(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          turnCount: 10,
          vowId: 'no_dejar_a_nadie',
          vowStatus: 'puesto_a_prueba',
          vowTestedCount: 2,
        ),
      ]);
      await _pumpProfile(tester, controller);

      expect(find.textContaining('Puesto a prueba 2 veces'), findsOneWidget);
    });

    testWidgets('omits a vow that was never tested from the list', (tester) async {
      final controller = _controllerWith([
        const SessionReadingStat(
          sessionId: 's1',
          worldSlug: 'isekai',
          status: 'active',
          turnCount: 10,
          vowId: 'no_dejar_a_nadie',
        ),
      ]);
      await _pumpProfile(tester, controller);

      expect(find.textContaining('Sostenido'), findsNothing);
      expect(find.textContaining('Puesto a prueba'), findsNothing);
      expect(find.textContaining('ningún juramento fue puesto a prueba'), findsOneWidget);
    });

    testWidgets('shows zeros and no per-world/vow content for a brand-new account',
        (tester) async {
      final controller = _controllerWith(const []);
      await _pumpProfile(tester, controller);

      expect(find.text('0'), findsWidgets);
      expect(find.textContaining('Todavía no empezaste ninguna historia'), findsOneWidget);
    });
  });
}
