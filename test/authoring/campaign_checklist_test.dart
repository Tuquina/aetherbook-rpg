import 'package:aetherbook/core/authoring/campaign_checklist.dart';
import 'package:aetherbook/core/authoring/campaign_draft.dart';
import 'package:aetherbook/core/authoring/campaign_graph_edits.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/hub_activity.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:flutter_test/flutter_test.dart';

CampaignDraft _draft({
  String title = 'Título',
  String synopsis = 'Sinopsis',
  bool aiRuntimeRequired = true,
  required StoryGraph graph,
}) {
  return CampaignDraft(
    authorId: 'author-1',
    slug: 'historia',
    title: title,
    synopsis: synopsis,
    baseWorldSlug: 'xianxia',
    aiRuntimeRequired: aiRuntimeRequired,
    graph: graph,
  );
}

void main() {
  group('CampaignChecklist.blocking — basics', () {
    test('flags a missing title/synopsis', () {
      final draft = _draft(
        title: '',
        graph: const StoryGraph(startNodeId: 'a', nodes: {'a': FixedAnchorNode(id: 'a')}),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('título')), isTrue);
    });

    test('flags an empty graph and stops there', () {
      final draft = _draft(graph: const StoryGraph(startNodeId: '', nodes: {}));
      final issues = CampaignChecklist.blocking(draft);
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('ninguna escena'));
    });

    test('flags a missing start node', () {
      final draft = _draft(
        graph: const StoryGraph(startNodeId: '', nodes: {'a': FixedAnchorNode(id: 'a')}),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('inicio')), isTrue);
    });

    test('flags having no endings at all', () {
      final draft = _draft(
        graph: const StoryGraph(startNodeId: 'a', nodes: {'a': FixedAnchorNode(id: 'a')}),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('ningún final')), isTrue);
    });

    test('a minimally valid campaign (start -> ending) has no blocking issues', () {
      final draft = _draft(
        title: 'X',
        synopsis: 'Y',
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'end'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [
            Ending(id: 'e1', visibleChoice: 'Terminar'),
          ]),
        }),
      );
      expect(CampaignChecklist.blocking(draft), isEmpty);
    });
  });

  group('CampaignChecklist.blocking — graph structure', () {
    test('flags a dangling choice target', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'nowhere'),
          ]),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('nowhere')), isTrue);
    });

    test('flags a node unreachable from the start', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'end'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
          'orphan': const FixedAnchorNode(id: 'orphan'),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.nodeId == 'orphan' && i.message.contains('alcanzar')), isTrue);
    });

    test('flags a reachable node that can never reach an ending', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'b'),
            CampaignGraphEdits.blankChoice(label: 'terminar', targetNodeId: 'end'),
          ]),
          // b loops back to a — reachable, but never reaches an ending.
          'b': FixedAnchorNode(id: 'b', choices: [
            CampaignGraphEdits.blankChoice(label: 'volver', targetNodeId: 'a'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.nodeId == 'b' && i.message.contains('ningún final')), isFalse,
          reason: 'b can still reach an ending via a, even though it also loops');
    });

    test('a dead-end branch that never reaches an ending is flagged', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'deadend'),
            CampaignGraphEdits.blankChoice(label: 'terminar', targetNodeId: 'end'),
          ]),
          'deadend': const FixedAnchorNode(id: 'deadend'),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(
        issues.any((i) => i.nodeId == 'deadend' && i.message.contains('ningún final')),
        isTrue,
      );
    });
  });

  group('CampaignChecklist.blocking — offline-playable text', () {
    test('flags an unconditional choice with no resultText when AI is off', () {
      final draft = _draft(
        aiRuntimeRequired: false,
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            const StoryChoice(label: 'ir', targetNodeId: 'end'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('ir') && i.message.contains('texto')), isTrue);
    });

    test('does not flag missing resultText when the AI narrator is required', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            const StoryChoice(label: 'ir', targetNodeId: 'end'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      expect(CampaignChecklist.blocking(draft), isEmpty);
    });

    test('a checked choice needs text on both sale bien and sale mal', () {
      final draft = _draft(
        aiRuntimeRequired: false,
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            const StoryChoice(
              label: 'forzar',
              targetNodeId: 'end',
              checkAttribute: 'cultivo',
              checkDifficulty: 15,
              onSuccess: ChoiceOutcome(resultText: 'bien'),
              // onFailure missing on purpose
            ),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('sale mal')), isTrue);
      expect(issues.any((i) => i.message.contains('sale bien')), isFalse);
    });

    test('a fully-authored checked choice passes', () {
      final draft = _draft(
        aiRuntimeRequired: false,
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            const StoryChoice(
              label: 'forzar',
              targetNodeId: 'end',
              checkAttribute: 'cultivo',
              checkDifficulty: 15,
              onSuccess: ChoiceOutcome(resultText: 'bien'),
              onFailure: ChoiceOutcome(resultText: 'mal'),
            ),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      expect(CampaignChecklist.blocking(draft), isEmpty);
    });

    test('checks a state hub\'s activities too, not just its exits', () {
      final draft = _draft(
        aiRuntimeRequired: false,
        graph: StoryGraph(startNodeId: 'hub', nodes: {
          'hub': StateHubNode(
            id: 'hub',
            activities: const [HubActivity(id: 'act1', label: 'descansar')],
            exits: [CampaignGraphEdits.blankChoice(label: 'salir', targetNodeId: 'end')],
          ),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      final issues = CampaignChecklist.blocking(draft);
      expect(issues.any((i) => i.message.contains('descansar')), isTrue);
    });
  });

  group('CampaignChecklist.advisory', () {
    test('flags an ending whose hard-requirement flag is never set anywhere', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'end'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [
            Ending(
              id: 'e1',
              visibleChoice: 'Un final especial',
              hardRequirement: FlagGate('nunca_activada'),
            ),
          ]),
        }),
      );
      final issues = CampaignChecklist.advisory(draft);
      expect(issues, hasLength(1));
      expect(issues.single.message, contains('Un final especial'));
      expect(issues.single.detail, contains('nunca_activada'));
    });

    test('does not flag an ending whose flag is actually set somewhere', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            StoryChoice(
              label: 'activar',
              targetNodeId: 'end',
              effects: const [StateDelta(type: StateDeltaType.flag, key: 'la_bandera', value: true)],
            ),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [
            Ending(id: 'e1', visibleChoice: 'x', hardRequirement: FlagGate('la_bandera')),
          ]),
        }),
      );
      expect(CampaignChecklist.advisory(draft), isEmpty);
    });

    test('an AlwaysGate ending is never flagged (nothing to set)', () {
      final draft = _draft(
        graph: StoryGraph(startNodeId: 'a', nodes: {
          'a': FixedAnchorNode(id: 'a', choices: [
            CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'end'),
          ]),
          'end': const ResolutionNode(id: 'end', endings: [Ending(id: 'e1', visibleChoice: 'x')]),
        }),
      );
      expect(CampaignChecklist.advisory(draft), isEmpty);
    });
  });
}
