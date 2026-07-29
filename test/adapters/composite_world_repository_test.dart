import 'dart:typed_data';

import 'package:aetherbook/adapters/content/composite_world_repository.dart';
import 'package:aetherbook/core/authoring/campaign_draft.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/campaign_draft_repository_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAssetWorldRepository implements WorldRepositoryPort {
  _FakeAssetWorldRepository(this.worlds);
  final Map<String, World> worlds;

  @override
  Future<World> loadWorld(String slug) async {
    final world = worlds[slug];
    if (world == null) throw Exception('asset not found: $slug');
    return world;
  }
}

class _FakeCampaignDraftRepository implements CampaignDraftRepositoryPort {
  _FakeCampaignDraftRepository(this.officialBySlug);
  final Map<String, CampaignDraft> officialBySlug;

  @override
  Future<CampaignDraft?> loadOfficialBySlug(String slug) async => officialBySlug[slug];

  @override
  Future<List<CampaignDraftSummary>> listMine() => throw UnimplementedError();
  @override
  Future<List<CampaignDraftSummary>> listOfficial() => throw UnimplementedError();
  @override
  Future<CampaignDraft?> loadDraft(String id) => throw UnimplementedError();
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

World _world(String slug, {String name = 'Mundo'}) {
  return World(
    slug: slug,
    name: name,
    theme: '',
    tone: '',
    systemPrompt: 'prompt',
    imageStyleSuffix: '',
    defaultDifficulty: 12,
    criticalMargin: 5,
    primaryAttribute: 'cuerpo',
    startingCharacter: const Character(
        name: 'P', level: 1, exp: 0, attributes: {'cuerpo': 1}, resources: {}),
    seedNarration: '',
    seedChoices: const [],
  );
}

CampaignDraft _officialDraft({World? customWorld, String? baseWorldSlug}) {
  return CampaignDraft(
    authorId: 'admin-1',
    slug: 'historia-oficial',
    title: 'Historia oficial',
    customWorld: customWorld,
    baseWorldSlug: baseWorldSlug,
    aiRuntimeRequired: true,
    graph: StoryGraph(
      startNodeId: 'p1',
      nodes: {'p1': const FixedAnchorNode(id: 'p1', narration: 'Inicio.')},
    ),
    officialModule: CampaignOfficialModule.hybrid,
  );
}

void main() {
  test('loads a bundled asset world without touching campaign_drafts', () async {
    final assets = _FakeAssetWorldRepository({'xianxia': _world('xianxia')});
    final campaignDrafts = _FakeCampaignDraftRepository({});
    final repo = CompositeWorldRepository(assets: assets, campaignDrafts: campaignDrafts);

    final world = await repo.loadWorld('xianxia');
    expect(world.slug, 'xianxia');
  });

  test('falls back to an official custom-world campaign when the asset is missing', () async {
    final assets = _FakeAssetWorldRepository({});
    final campaignDrafts = _FakeCampaignDraftRepository({
      'historia-oficial': _officialDraft(customWorld: _world('mundo-personalizado', name: 'Custom')),
    });
    final repo = CompositeWorldRepository(assets: assets, campaignDrafts: campaignDrafts);

    final world = await repo.loadWorld('historia-oficial');
    expect(world.slug, 'historia-oficial');
    expect(world.name, 'Historia oficial');
    expect(world.storyGraph!.nodes.keys, {'p1'});
  });

  test('falls back to an official base-world campaign, loading the base world too', () async {
    final assets = _FakeAssetWorldRepository({'xianxia': _world('xianxia', name: 'Xianxia')});
    final campaignDrafts = _FakeCampaignDraftRepository({
      'historia-oficial': _officialDraft(baseWorldSlug: 'xianxia'),
    });
    final repo = CompositeWorldRepository(assets: assets, campaignDrafts: campaignDrafts);

    final world = await repo.loadWorld('historia-oficial');
    expect(world.slug, 'historia-oficial');
    expect(world.primaryAttribute, 'cuerpo');
  });

  test('throws when neither an asset nor an official campaign match the slug', () async {
    final assets = _FakeAssetWorldRepository({});
    final campaignDrafts = _FakeCampaignDraftRepository({});
    final repo = CompositeWorldRepository(assets: assets, campaignDrafts: campaignDrafts);

    expect(() => repo.loadWorld('no-existe'), throwsStateError);
  });
}
