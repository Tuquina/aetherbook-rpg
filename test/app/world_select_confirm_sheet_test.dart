// V2 Stage 2: WorldSelectScreen's abandon/restart confirmations moved from
// showDialog/AlertDialog to showConfirmSheet (lib/app/widgets/confirm_sheet.dart).
// Neither call site had widget-test coverage before this file -- only
// GameController.abandonStory's *delegation* to persistence was covered
// (game_controller_persistence_test.dart), never the confirmation UI itself.
import 'dart:typed_data';

import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/app/world_select_screen.dart';
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/core/authoring/campaign_draft.dart';
import 'package:aetherbook/core/engine/action_resolution.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/campaign_draft_repository_port.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Admin Stage 5: `curated_zombie_01_ultimo_tren` no longer lives in
/// [WorldSelectScreen]'s hardcoded `_availableWorldSlugs` — it's a published
/// official `campaign_drafts` row now, merged into the catalog dynamically
/// via `listOfficial()`. This fake stands in for that merge so the test
/// below can still exercise a real `StoryModule.complete` restart.
class _FakeOfficialCampaignRepository implements CampaignDraftRepositoryPort {
  @override
  Future<List<CampaignDraftSummary>> listOfficial() async => [
        CampaignDraftSummary(
          id: 'draft-1',
          slug: 'curated_zombie_01_ultimo_tren',
          title: 'El último tren no espera a los vivos',
          status: CampaignDraftStatus.published,
          nodeCount: 1,
          updatedAt: DateTime.now(),
          officialModule: CampaignOfficialModule.complete,
        ),
      ];

  @override
  Future<List<CampaignDraftSummary>> listMine() => throw UnimplementedError();
  @override
  Future<List<CampaignDraftSummary>> listExplorable() => throw UnimplementedError();
  @override
  Future<CampaignDraft?> loadDraft(String id) => throw UnimplementedError();
  @override
  Future<CampaignDraft?> loadPublishedBySlug(String slug) => throw UnimplementedError();
  @override
  Future<CampaignDraft> createDraft({required String baseWorldSlug, required String title}) =>
      throw UnimplementedError();
  @override
  Future<CampaignDraft> createOfficialDraft({
    required World customWorld,
    required CampaignOfficialModule officialModule,
  }) =>
      throw UnimplementedError();
  @override
  Future<void> saveDraft(CampaignDraft draft) => throw UnimplementedError();
  @override
  Future<void> deleteDraft(String id) => throw UnimplementedError();
  @override
  Future<void> publishDraft(String id, {required DateTime licenseAcceptedAt}) =>
      throw UnimplementedError();
  @override
  Future<void> unpublishDraft(String id) => throw UnimplementedError();
  @override
  Future<String> uploadCoverImage(String id, Uint8List bytes, {required String fileExtension}) =>
      throw UnimplementedError();
}

const _storyGraph = StoryGraph(
  startNodeId: 'inicio',
  nodes: {
    'inicio': FixedAnchorNode(
        id: 'inicio', narration: 'Todo comienza aquí.', choices: []),
  },
);

/// Every slug resolves to a distinct freeform (no `storyGraph`) world, except
/// `curated_zombie_01_ultimo_tren`, which gets a real (if tiny) curated
/// graph — enough to land it in `StoryModule.complete` ("Historias
/// completas"), where the restart affordance lives.
class _MixedWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async {
    if (slug == 'curated_zombie_01_ultimo_tren') {
      return World(
        slug: slug,
        name: 'El último tren no espera a los vivos',
        theme: 'postapoc_zombie',
        tone: 'tenso',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'reflejos',
        storyGraph: _storyGraph,
        aiRuntimeRequired: false,
        allowFreeText: false,
        startingCharacter: const Character(
          name: 'Protagonista',
          level: 1,
          exp: 0,
          attributes: {'reflejos': 2},
          resources: {},
        ),
        seedNarration: '',
        seedChoices: const [],
      );
    }
    return World(
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
}

/// In-memory persistence fake (same shape used throughout test/app/) — only
/// what this file needs, plus `abandonedSessionIds` to assert the abandon
/// confirmation actually delegates.
class _FakeGameStateRepository implements GameStateRepositoryPort {
  List<GameSessionSummary> summariesToReturn = const [];
  final List<String> abandonedSessionIds = [];

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => null;

  @override
  Future<GameSession?> loadSession(String sessionId) async => null;

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
  }) async =>
      GameSession(id: 'new-session', worldSlug: worldSlug, character: character);

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
  Future<void> saveCharacterAvatar({
    required String sessionId,
    required String avatarUrl,
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
  Future<void> abandonSession(String sessionId) async {
    abandonedSessionIds.add(sessionId);
  }

  @override
  Future<void> completeSession(String sessionId) async {}

  @override
  Future<List<SessionReadingStat>> readingStats() async => const [];

  @override
  Future<List<SessionLibraryEntry>> storyLibrary() async => const [];
}

void main() {
  testWidgets(
      'abandoning a saved story shows a ConfirmSheet (not an AlertDialog) '
      'and only calls abandonSession after confirming', (tester) async {
    // The home dashboard now has 3 responsive layouts (V2 §8a/§8b/§2a) —
    // force the mobile one, since that's what this test actually exercises,
    // rather than incidentally landing in tablet mode at the default
    // 800x600 test surface.
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final persistence = _FakeGameStateRepository()
      ..summariesToReturn = [
        GameSessionSummary(
          id: 'story-1',
          worldSlug: 'isekai',
          characterName: 'Fernando',
          updatedAt: DateTime.now(),
        ),
      ];

    final controller = GameController(
      worldRepository: _MixedWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      persistence: persistence,
      dice: const FixedDice(10),
    );

    await tester
        .pumpWidget(MaterialApp(home: WorldSelectScreen(controller: controller)));
    await tester.pump();

    await tester.tap(find.text('Crea tu propia historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Opens the sheet, doesn't abandon yet. Fixed-duration pump()s, not
    // pumpAndSettle() -- AetherBackground's ambient animation never settles
    // (same reason widget_test.dart/account_screen_test.dart avoid it).
    await tester.tap(find.byTooltip('Abandonar historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Fernando'), findsWidgets); // sheet title + card, both visible
    expect(find.textContaining('No se puede deshacer'), findsOneWidget);
    expect(find.text('Abandonar'), findsOneWidget);
    expect(persistence.abandonedSessionIds, isEmpty);

    await tester.tap(find.text('Abandonar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(persistence.abandonedSessionIds, ['story-1']);
  });

  testWidgets(
      'restarting a curated story shows a ConfirmSheet and only restarts '
      'after confirming', (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = GameController(
      worldRepository: _MixedWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      dice: const FixedDice(10),
      campaignDrafts: _FakeOfficialCampaignRepository(),
    );

    await tester
        .pumpWidget(MaterialApp(home: WorldSelectScreen(controller: controller)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Historias completas'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Reiniciar historia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('El último tren no espera a los vivos'), findsWidgets);
    expect(find.textContaining('El progreso actual se pierde'), findsOneWidget);
    expect(find.text('Reiniciar'), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);

    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(GameScreen), findsOneWidget);
    expect(controller.world?.slug, 'curated_zombie_01_ultimo_tren');
  });
}
