import 'package:aetherbook/adapters/persistence/campaign_draft_mappers.dart';
import 'package:aetherbook/core/authoring/campaign_draft.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

World _customWorld() {
  return const World(
    slug: 'mundo-personalizado',
    name: 'Mundo personalizado',
    theme: 'noir',
    tone: 'tenso',
    systemPrompt: 'Narra en tono noir.',
    imageStyleSuffix: ', estilo noir',
    defaultDifficulty: 12,
    criticalMargin: 5,
    primaryAttribute: 'astucia',
    attributeKeys: ['astucia', 'temple'],
    startingCharacter: Character(
      name: 'Protagonista',
      level: 1,
      exp: 0,
      attributes: {'astucia': 2, 'temple': 1},
      resources: {},
    ),
    seedNarration: 'La lluvia no para desde ayer.',
    seedChoices: ['Investigar', 'Esperar'],
  );
}

CampaignDraft _draft({String? id}) {
  return CampaignDraft(
    id: id,
    authorId: 'author-1',
    slug: 'la-ceniza-sobre-kaido',
    title: 'La ceniza sobre Kaido',
    synopsis: 'Alguien quemó el registro de deudas del pueblo.',
    baseWorldSlug: 'xianxia',
    status: CampaignDraftStatus.draft,
    contentWarnings: const ['violencia', 'muerte_de_un_personaje'],
    coverImageUrl: 'https://cdn.aetherbook.dev/campaign-covers/a1/cover.jpg',
    estimatedDurationMinutes: 300,
    aiRuntimeRequired: true,
    graph: StoryGraph(
      startNodeId: 'p1',
      nodes: {
        'p1': const FixedAnchorNode(id: 'p1', narration: 'La orilla huele a ceniza.'),
      },
    ),
    nodeTitles: const {'p1': 'El barco de ceniza'},
  );
}

void main() {
  group('campaignDraftToRow / campaignDraftFromRow', () {
    test('round-trips a draft through row shape', () {
      final draft = _draft(id: 'draft-1');
      final row = campaignDraftToRow(draft);

      expect(row['id'], 'draft-1');
      expect(row['author_id'], 'author-1');
      expect(row['slug'], 'la-ceniza-sobre-kaido');
      expect(row['status'], 'draft');
      expect(row['content_warnings'], ['violencia', 'muerte_de_un_personaje']);
      expect(row['graph'], isA<Map<String, dynamic>>());

      final restored = campaignDraftFromRow(row.cast<String, dynamic>());
      expect(restored.id, draft.id);
      expect(restored.authorId, draft.authorId);
      expect(restored.slug, draft.slug);
      expect(restored.title, draft.title);
      expect(restored.synopsis, draft.synopsis);
      expect(restored.baseWorldSlug, draft.baseWorldSlug);
      expect(restored.status, draft.status);
      expect(restored.contentWarnings, draft.contentWarnings);
      expect(restored.coverImageUrl, draft.coverImageUrl);
      expect(restored.estimatedDurationMinutes, draft.estimatedDurationMinutes);
      expect(restored.aiRuntimeRequired, draft.aiRuntimeRequired);
      expect(restored.graph.startNodeId, draft.graph.startNodeId);
      expect(restored.graph.nodes.keys, draft.graph.nodes.keys);
      expect(restored.nodeTitles, draft.nodeTitles);
      expect(restored.titleForNode('p1'), 'El barco de ceniza');
      expect(restored.titleForNode('missing'), 'missing');
    });

    test('a published draft round-trips its publish timestamps', () {
      final draft = _draft(id: 'draft-2').copyWith(
        status: CampaignDraftStatus.published,
        licenseAcceptedAt: DateTime.utc(2026, 7, 28, 10),
        publishedAt: DateTime.utc(2026, 7, 28, 10, 1),
      );
      final row = campaignDraftToRow(draft);
      final restored = campaignDraftFromRow(row.cast<String, dynamic>());

      expect(restored.status, CampaignDraftStatus.published);
      expect(restored.isPublished, isTrue);
      expect(restored.licenseAcceptedAt, draft.licenseAcceptedAt);
      expect(restored.publishedAt, draft.publishedAt);
    });

    test('round-trips an official module flag', () {
      final draft = _draft(id: 'draft-5')
          .copyWith(officialModule: CampaignOfficialModule.hybrid);
      final row = campaignDraftToRow(draft);
      expect(row['official_module'], 'hybrid');

      final restored = campaignDraftFromRow(row.cast<String, dynamic>());
      expect(restored.officialModule, CampaignOfficialModule.hybrid);
    });

    test('officialModule stays null for an ordinary community novel', () {
      final draft = _draft(id: 'draft-6');
      final row = campaignDraftToRow(draft);
      expect(row['official_module'], isNull);

      final restored = campaignDraftFromRow(row.cast<String, dynamic>());
      expect(restored.officialModule, isNull);
    });

    test('copyWith(clearOfficialModule: true) demotes an official campaign back to null', () {
      final draft =
          _draft(id: 'draft-7').copyWith(officialModule: CampaignOfficialModule.complete);
      expect(draft.officialModule, CampaignOfficialModule.complete);
      final demoted = draft.copyWith(clearOfficialModule: true);
      expect(demoted.officialModule, isNull);
    });

    test('a custom-world draft round-trips its world and drops baseWorldSlug', () {
      final draft = CampaignDraft(
        id: 'draft-9',
        authorId: 'author-1',
        slug: 'mundo-personalizado',
        title: 'Mundo personalizado',
        customWorld: _customWorld(),
        graph: const StoryGraph(startNodeId: '', nodes: {}),
      );
      final row = campaignDraftToRow(draft);
      expect(row['base_world_slug'], isNull);
      expect(row['custom_world'], isA<Map<String, dynamic>>());
      // The graph lives in its own column — never duplicated inside custom_world.
      expect((row['custom_world']! as Map).containsKey('graph'), isFalse);

      final restored = campaignDraftFromRow(row.cast<String, dynamic>());
      expect(restored.baseWorldSlug, isNull);
      expect(restored.customWorld, isNotNull);
      expect(restored.customWorld!.slug, 'mundo-personalizado');
      expect(restored.customWorld!.attributeKeys, ['astucia', 'temple']);
      expect(restored.customWorld!.storyGraph, isNull);
    });
  });

  group('campaignDraftSummaryFromRow', () {
    test('counts nodes from the embedded graph without a full parse', () {
      final draft = _draft(id: 'draft-3');
      final row = campaignDraftToRow(draft)..['updated_at'] = '2026-07-28T10:00:00Z';

      final summary = campaignDraftSummaryFromRow(row.cast<String, dynamic>());
      expect(summary.id, 'draft-3');
      expect(summary.title, draft.title);
      expect(summary.nodeCount, 1);
      expect(summary.status, CampaignDraftStatus.draft);
    });

    test('nodeCount is 0 for a brand-new empty draft', () {
      final row = {
        'id': 'draft-4',
        'slug': 'nueva-historia',
        'title': '',
        'base_world_slug': 'xianxia',
        'status': 'draft',
        'graph': {'start_node': '', 'nodes': <String, dynamic>{}},
        'updated_at': '2026-07-28T10:00:00Z',
      };
      final summary = campaignDraftSummaryFromRow(row);
      expect(summary.nodeCount, 0);
    });

    test('reads officialModule when present on the row', () {
      final row = {
        'id': 'draft-8',
        'slug': 'historia-oficial',
        'title': '',
        'base_world_slug': 'xianxia',
        'status': 'published',
        'graph': {'start_node': '', 'nodes': <String, dynamic>{}},
        'updated_at': '2026-07-30T10:00:00Z',
        'official_module': 'complete',
      };
      final summary = campaignDraftSummaryFromRow(row);
      expect(summary.officialModule, CampaignOfficialModule.complete);
    });
  });

  group('slugify', () {
    test('lowercases, strips accents and punctuation, hyphenates spaces', () {
      expect(slugify('La ceniza sobre Kaido'), 'la-ceniza-sobre-kaido');
      expect(slugify('¿Qué pasó con el Señor?'), 'que-paso-con-el-senor');
    });

    test('falls back to a default for an empty/symbols-only title', () {
      expect(slugify(''), 'historia');
      expect(slugify('¡¡¡!!!'), 'historia');
    });
  });
}
