// Admin Stage 4: ExplorarScreen lists published community novels
// (officialModule == null) — this test drives it with a fake port double
// instead of a real Supabase call, same isolation every other adapter-facing
// screen test in this codebase uses.

import 'dart:typed_data';

import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/explorar_screen.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/authoring/campaign_draft.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/campaign_draft_repository_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldRepository implements WorldRepositoryPort {
  _FakeWorldRepository(this.worlds);
  final Map<String, World> worlds;

  @override
  Future<World> loadWorld(String slug) async {
    final world = worlds[slug];
    if (world == null) throw Exception('not found: $slug');
    return world;
  }
}

class _FakeCampaignDraftRepository implements CampaignDraftRepositoryPort {
  _FakeCampaignDraftRepository(this.explorable);
  final List<CampaignDraftSummary> explorable;

  @override
  Future<List<CampaignDraftSummary>> listExplorable() async => explorable;

  @override
  Future<List<CampaignDraftSummary>> listMine() => throw UnimplementedError();
  @override
  Future<List<CampaignDraftSummary>> listOfficial() => throw UnimplementedError();
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

World _world(String slug) => World(
      slug: slug,
      name: 'Novela $slug',
      theme: 'xianxia',
      tone: 'épico',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: 'cuerpo',
      startingCharacter: const Character(
          name: 'P', level: 1, exp: 0, attributes: {}, resources: {}),
      seedNarration: '',
      seedChoices: const [],
    );

CampaignDraftSummary _summary(String slug) => CampaignDraftSummary(
      id: slug,
      slug: slug,
      title: 'Novela $slug',
      status: CampaignDraftStatus.published,
      nodeCount: 3,
      updatedAt: DateTime.utc(2026, 7, 30),
    );

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget child) async {
    // `disableAnimations: true` stops `AetherBackground`'s never-ending
    // particle drift so a fixed pump count is enough to settle — same
    // gotcha `world_select_responsive_test.dart` hit.
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(home: child),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the empty state without a campaignDrafts port', (tester) async {
    final controller = GameController(
      worldRepository: _FakeWorldRepository({}),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
    );
    await pumpScreen(tester, ExplorarScreen(controller: controller));

    expect(find.text('Todavía no hay novelas publicadas por la comunidad.'), findsOneWidget);
  });

  testWidgets('lists every published community novel as a story card', (tester) async {
    final campaignDrafts = _FakeCampaignDraftRepository([_summary('novela-1'), _summary('novela-2')]);
    final controller = GameController(
      worldRepository: _FakeWorldRepository({
        'novela-1': _world('novela-1'),
        'novela-2': _world('novela-2'),
      }),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      campaignDrafts: campaignDrafts,
    );
    await pumpScreen(tester, ExplorarScreen(controller: controller));

    expect(find.text('Novela novela-1'), findsOneWidget);
    expect(find.text('Novela novela-2'), findsOneWidget);
  });
}
