import 'package:aetherbook/core/authoring/campaign_draft.dart';
import 'package:aetherbook/core/authoring/campaign_materializer.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

World _baseWorld() {
  return const World(
    slug: 'xianxia',
    name: 'Xianxia',
    theme: 'xianxia',
    tone: 'épico',
    systemPrompt: 'Narra en tono épico.',
    imageStyleSuffix: ', estilo xianxia',
    defaultDifficulty: 12,
    criticalMargin: 5,
    primaryAttribute: 'cuerpo',
    catalogDescription: 'Descripción del mundo base.',
    estimatedDurationMinutes: 120,
    contentWarning: 'Aviso base.',
    aiRuntimeRequired: false,
    startingCharacter: Character(
      name: 'Protagonista',
      level: 1,
      exp: 0,
      attributes: {'cuerpo': 1},
      resources: {},
    ),
    seedNarration: '',
    seedChoices: [],
  );
}

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
    startingCharacter: Character(
      name: 'Protagonista',
      level: 1,
      exp: 0,
      attributes: {'astucia': 2},
      resources: {},
    ),
    seedNarration: '',
    seedChoices: [],
  );
}

CampaignDraft _draft({World? customWorld, String? baseWorldSlug}) {
  return CampaignDraft(
    authorId: 'admin-1',
    slug: 'historia-oficial',
    title: 'Historia oficial',
    synopsis: 'Una sinopsis distinta a la del mundo base.',
    baseWorldSlug: baseWorldSlug,
    customWorld: customWorld,
    estimatedDurationMinutes: 240,
    aiRuntimeRequired: true,
    contentWarnings: const ['violencia'],
    graph: StoryGraph(
      startNodeId: 'p1',
      nodes: {'p1': const FixedAnchorNode(id: 'p1', narration: 'Empieza acá.')},
    ),
    officialModule: CampaignOfficialModule.hybrid,
  );
}

void main() {
  test('materializes a custom-world draft as-is, overriding graph and metadata', () {
    final draft = _draft(customWorld: _customWorld());
    final world = materializeOfficialWorld(draft);

    expect(world.slug, 'historia-oficial');
    expect(world.name, 'Historia oficial');
    expect(world.catalogDescription, 'Una sinopsis distinta a la del mundo base.');
    expect(world.estimatedDurationMinutes, 240);
    expect(world.contentWarning, 'violencia');
    expect(world.aiRuntimeRequired, isTrue);
    expect(world.storyGraph, isNotNull);
    expect(world.storyGraph!.nodes.keys, {'p1'});
    // Everything else is untouched from the custom world.
    expect(world.primaryAttribute, 'astucia');
    expect(world.theme, 'noir');
  });

  test('materializes a base-world draft on top of the loaded base world', () {
    final draft = _draft(baseWorldSlug: 'xianxia');
    final world = materializeOfficialWorld(draft, baseWorld: _baseWorld());

    expect(world.slug, 'historia-oficial');
    expect(world.name, 'Historia oficial');
    expect(world.primaryAttribute, 'cuerpo');
    expect(world.storyGraph!.nodes.keys, {'p1'});
  });

  test('falls back to the base/custom world metadata when the draft leaves it blank', () {
    final draft = CampaignDraft(
      authorId: 'admin-1',
      slug: 'historia-oficial-2',
      customWorld: _customWorld(),
      graph: const StoryGraph(startNodeId: '', nodes: {}),
    );
    final world = materializeOfficialWorld(draft);

    expect(world.name, 'Mundo personalizado');
    expect(world.catalogDescription, isNull);
    expect(world.estimatedDurationMinutes, isNull);
    expect(world.contentWarning, isNull);
  });

  test('throws when the draft has neither a customWorld nor a supplied baseWorld', () {
    final draft = _draft(baseWorldSlug: 'xianxia');
    expect(() => materializeOfficialWorld(draft), throwsArgumentError);
  });
}
