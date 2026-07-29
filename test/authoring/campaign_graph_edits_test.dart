import 'package:aetherbook/core/authoring/campaign_graph_edits.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CampaignGraphEdits.blankNode', () {
    test('creates a minimally-valid node per kind', () {
      expect(CampaignGraphEdits.blankNode('a', NodeKind.fixedAnchor), isA<FixedAnchorNode>());
      expect(
        CampaignGraphEdits.blankNode('b', NodeKind.boundedCorridor),
        isA<BoundedCorridorNode>(),
      );
      expect(CampaignGraphEdits.blankNode('c', NodeKind.stateHub), isA<StateHubNode>());
      expect(CampaignGraphEdits.blankNode('d', NodeKind.resolution), isA<ResolutionNode>());
    });
  });

  group('CampaignGraphEdits.withNode / withoutNode', () {
    test('withNode upserts by id without disturbing other nodes', () {
      const graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a', narration: 'uno'),
      });
      final updated = CampaignGraphEdits.withNode(
        graph,
        const FixedAnchorNode(id: 'b', narration: 'dos'),
      );
      expect(updated.nodes.keys, {'a', 'b'});
      expect(updated.startNodeId, 'a');
    });

    test('withoutNode removes the node and clears startNodeId if it was the start', () {
      const graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a'),
        'b': FixedAnchorNode(id: 'b'),
      });
      final updated = CampaignGraphEdits.withoutNode(graph, 'a');
      expect(updated.nodes.keys, {'b'});
      expect(updated.startNodeId, '');
    });

    test('withoutNode leaves startNodeId untouched when removing a non-start node', () {
      const graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a'),
        'b': FixedAnchorNode(id: 'b'),
      });
      final updated = CampaignGraphEdits.withoutNode(graph, 'b');
      expect(updated.startNodeId, 'a');
    });
  });

  group('CampaignGraphEdits choice editing', () {
    test('supportsChoices is false only for ResolutionNode', () {
      expect(CampaignGraphEdits.supportsChoices(const FixedAnchorNode(id: 'a')), isTrue);
      expect(
        CampaignGraphEdits.supportsChoices(
          const BoundedCorridorNode(id: 'a', goal: '', turnBudget: 1, fallbackExitNodeId: 'x'),
        ),
        isTrue,
      );
      expect(CampaignGraphEdits.supportsChoices(const StateHubNode(id: 'a')), isTrue);
      expect(CampaignGraphEdits.supportsChoices(const ResolutionNode(id: 'a')), isFalse);
    });

    test('withAddedChoice appends to a FixedAnchorNode\'s choices', () {
      const node = FixedAnchorNode(id: 'a', narration: 'texto');
      final choice = CampaignGraphEdits.blankChoice(label: 'ir', targetNodeId: 'b');
      final updated = CampaignGraphEdits.withAddedChoice(node, choice) as FixedAnchorNode;
      expect(updated.narration, 'texto');
      expect(updated.choices, [choice]);
    });

    test('withAddedChoice appends to a StateHubNode\'s exits, not activities', () {
      const node = StateHubNode(id: 'a');
      final choice = CampaignGraphEdits.blankChoice(label: 'salir', targetNodeId: 'b');
      final updated = CampaignGraphEdits.withAddedChoice(node, choice) as StateHubNode;
      expect(updated.exits, [choice]);
      expect(updated.activities, isEmpty);
    });

    test('withAddedChoice throws for a ResolutionNode', () {
      const node = ResolutionNode(id: 'a');
      final choice = CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'b');
      expect(() => CampaignGraphEdits.withAddedChoice(node, choice), throwsArgumentError);
    });

    test('withChoiceReplacedAt swaps in place, keeping the same position', () {
      final choices = [
        CampaignGraphEdits.blankChoice(label: 'uno', targetNodeId: 'x'),
        CampaignGraphEdits.blankChoice(label: 'dos', targetNodeId: 'y'),
      ];
      final node = FixedAnchorNode(id: 'a', choices: choices);
      final replacement = CampaignGraphEdits.blankChoice(label: 'dos-editado', targetNodeId: 'z');
      final updated =
          CampaignGraphEdits.withChoiceReplacedAt(node, 1, replacement) as FixedAnchorNode;
      expect(updated.choices.map((c) => c.label), ['uno', 'dos-editado']);
    });

    test('withRemovedChoiceAt removes by index and preserves order of the rest', () {
      final choices = [
        CampaignGraphEdits.blankChoice(label: 'uno', targetNodeId: 'x'),
        CampaignGraphEdits.blankChoice(label: 'dos', targetNodeId: 'y'),
        CampaignGraphEdits.blankChoice(label: 'tres', targetNodeId: 'z'),
      ];
      final node = FixedAnchorNode(id: 'a', choices: choices);
      final updated = CampaignGraphEdits.withRemovedChoiceAt(node, 1) as FixedAnchorNode;
      expect(updated.choices.map((c) => c.label), ['uno', 'tres']);
    });
  });

  group('CampaignGraphEdits.withBodyText', () {
    test('sets narration on a FixedAnchorNode', () {
      const node = FixedAnchorNode(id: 'a');
      final updated = CampaignGraphEdits.withBodyText(node, 'nuevo texto') as FixedAnchorNode;
      expect(updated.narration, 'nuevo texto');
    });

    test('sets goal on a BoundedCorridorNode', () {
      const node = BoundedCorridorNode(
          id: 'a', goal: '', turnBudget: 3, fallbackExitNodeId: 'x');
      final updated = CampaignGraphEdits.withBodyText(node, 'nueva meta') as BoundedCorridorNode;
      expect(updated.goal, 'nueva meta');
    });

    test('is a no-op for a StateHubNode', () {
      const node = StateHubNode(id: 'a');
      expect(CampaignGraphEdits.withBodyText(node, 'x'), same(node));
    });
  });

  group('CampaignGraphEdits.outgoingTargets', () {
    test('collects choice targets for a FixedAnchorNode', () {
      final node = FixedAnchorNode(id: 'a', choices: [
        CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'b'),
        CampaignGraphEdits.blankChoice(label: 'y', targetNodeId: 'c'),
      ]);
      expect(CampaignGraphEdits.outgoingTargets(node), ['b', 'c']);
    });

    test('includes the fallback exit for a BoundedCorridorNode', () {
      final node = BoundedCorridorNode(
        id: 'a',
        goal: 'g',
        turnBudget: 3,
        fallbackExitNodeId: 'fallback',
        choices: [CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'b')],
      );
      expect(CampaignGraphEdits.outgoingTargets(node), ['b', 'fallback']);
    });

    test('omits an empty (not-yet-assigned) fallback exit', () {
      const node = BoundedCorridorNode(
          id: 'a', goal: 'g', turnBudget: 3, fallbackExitNodeId: '');
      expect(CampaignGraphEdits.outgoingTargets(node), isEmpty);
    });

    test('is empty for a ResolutionNode (endings never target a node)', () {
      const node = ResolutionNode(id: 'a');
      expect(CampaignGraphEdits.outgoingTargets(node), isEmpty);
    });
  });

  group('CampaignGraphEdits.withFixedReveals / withForbiddenReveals', () {
    test('replaces fixedReveals on a FixedAnchorNode', () {
      const node = FixedAnchorNode(id: 'a', fixedReveals: ['x']);
      final updated =
          CampaignGraphEdits.withFixedReveals(node, ['y', 'z']) as FixedAnchorNode;
      expect(updated.fixedReveals, ['y', 'z']);
      expect(updated.forbiddenReveals, isEmpty);
    });

    test('replaces forbiddenReveals on a FixedAnchorNode', () {
      const node = FixedAnchorNode(id: 'a', forbiddenReveals: ['x']);
      final updated =
          CampaignGraphEdits.withForbiddenReveals(node, ['y']) as FixedAnchorNode;
      expect(updated.forbiddenReveals, ['y']);
    });

    test('is a no-op for a non-FixedAnchorNode', () {
      const node = StateHubNode(id: 'a');
      expect(CampaignGraphEdits.withFixedReveals(node, ['x']), same(node));
      expect(CampaignGraphEdits.withForbiddenReveals(node, ['x']), same(node));
    });
  });

  group('CampaignGraphEdits.flattenGate / buildGate', () {
    test('AlwaysGate flattens to an empty list', () {
      expect(CampaignGraphEdits.flattenGate(const AlwaysGate()), isEmpty);
    });

    test('a single simple gate flattens to itself', () {
      const gate = FlagGate('x');
      expect(CampaignGraphEdits.flattenGate(gate), [gate]);
    });

    test('an AllOfGate flattens to its children', () {
      const a = FlagGate('x');
      const b = MinAttributeGate('cultivo', 2);
      expect(CampaignGraphEdits.flattenGate(const AllOfGate([a, b])), [a, b]);
    });

    test('buildGate is the inverse of flattenGate for 0/1/many conditions', () {
      expect(CampaignGraphEdits.buildGate([]), isA<AlwaysGate>());
      const single = FlagGate('x');
      expect(CampaignGraphEdits.buildGate([single]), same(single));
      const a = FlagGate('x');
      const b = MinAttributeGate('cultivo', 2);
      final built = CampaignGraphEdits.buildGate([a, b]);
      expect(built, isA<AllOfGate>());
      expect((built as AllOfGate).gates, [a, b]);
    });
  });

  group('CampaignGraphEdits.bfsLayers', () {
    test('groups nodes by distance from the start node', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(
          id: 'a',
          choices: [CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'b')],
        ),
        'b': FixedAnchorNode(
          id: 'b',
          choices: [CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'c')],
        ),
        'c': const FixedAnchorNode(id: 'c'),
      });
      final layers = CampaignGraphEdits.bfsLayers(graph);
      expect(layers[0], ['a']);
      expect(layers[1], ['b']);
      expect(layers[2], ['c']);
    });

    test('a node unreachable from start lands in the final bucket', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(
          id: 'a',
          choices: [CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'b')],
        ),
        'b': const FixedAnchorNode(id: 'b'),
        'orphan': const FixedAnchorNode(id: 'orphan'),
      });
      final layers = CampaignGraphEdits.bfsLayers(graph);
      // Reachable depths are 0 (a) and 1 (b); the orphan lands one past that.
      expect(layers[2], ['orphan']);
    });

    test('two nodes converging on the same target both point forward (a graph, not a tree)', () {
      final graph = StoryGraph(startNodeId: 'a', nodes: {
        'a': FixedAnchorNode(id: 'a', choices: [
          CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'b'),
          CampaignGraphEdits.blankChoice(label: 'y', targetNodeId: 'c'),
        ]),
        'b': FixedAnchorNode(
          id: 'b',
          choices: [CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'd')],
        ),
        'c': FixedAnchorNode(
          id: 'c',
          choices: [CampaignGraphEdits.blankChoice(label: 'x', targetNodeId: 'd')],
        ),
        'd': const FixedAnchorNode(id: 'd'),
      });
      final layers = CampaignGraphEdits.bfsLayers(graph);
      expect(layers[1], containsAll(['b', 'c']));
      expect(layers[2], ['d']);
    });

    test('an empty startNodeId puts everything in the unreachable bucket', () {
      const graph = StoryGraph(startNodeId: '', nodes: {
        'a': FixedAnchorNode(id: 'a'),
        'b': FixedAnchorNode(id: 'b'),
      });
      final layers = CampaignGraphEdits.bfsLayers(graph);
      // maxDepth folds to 0 with no reachable nodes at all, so the
      // unreachable bucket is depth 1 (one past that).
      expect(layers.keys, [1]);
      expect(layers[1], containsAll(['a', 'b']));
    });
  });
}
