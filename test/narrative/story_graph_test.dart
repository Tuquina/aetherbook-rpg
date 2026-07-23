import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoryGraph.fromJson', () {
    test('parses nodes and resolves the start node', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'beat_1',
        'nodes': {
          'beat_1': {
            'narration': 'Inicio',
            'choices': [
              {'label': 'Avanzar', 'target': 'beat_2'},
            ],
          },
          'beat_2': {'narration': 'Fin'},
        },
      });

      expect(graph.startNodeId, 'beat_1');
      expect((graph.startNode as FixedAnchorNode).narration, 'Inicio');
      expect((graph.nodeById('beat_2') as FixedAnchorNode).narration, 'Fin');
    });

    test('is a graph, not a tree: two nodes can target the same node', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {
            'choices': [
              {'label': 'x', 'target': 'c'},
            ],
          },
          'b': {
            'choices': [
              {'label': 'y', 'target': 'c'},
            ],
          },
          'c': {'narration': 'Reconvergencia'},
        },
      });

      final fromA =
          (graph.nodeById('a') as FixedAnchorNode).choices.single.targetNodeId;
      final fromB =
          (graph.nodeById('b') as FixedAnchorNode).choices.single.targetNodeId;
      expect(fromA, 'c');
      expect(fromB, 'c');
      expect(graph.nodeById(fromA), same(graph.nodeById(fromB)));
    });
  });

  group('StoryGraph.nodeById', () {
    test('throws ArgumentError for an unknown node id', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {'narration': 'x'},
        },
      });
      expect(() => graph.nodeById('missing'), throwsArgumentError);
    });
  });

  group('StoryGraph.fromJson with mixed node types', () {
    test('dispatches each node to its declared type', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'p0',
        'nodes': {
          'p0': {'type': 'fixed_anchor', 'narration': 'Inicio'},
          'corridor': {
            'type': 'bounded_corridor',
            'goal': 'g',
            'turn_budget': 3,
            'fallback_exit': 'p0',
          },
          'hub': {'type': 'state_hub'},
          'ritual': {'type': 'resolution'},
        },
      });

      expect(graph.nodeById('p0'), isA<FixedAnchorNode>());
      expect(graph.nodeById('corridor'), isA<BoundedCorridorNode>());
      expect(graph.nodeById('hub'), isA<StateHubNode>());
      expect(graph.nodeById('ritual'), isA<ResolutionNode>());
    });
  });

  group('StoryGraph.unknownTargetIds', () {
    test('is empty when every reference resolves', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {
            'choices': [
              {'label': 'x', 'target': 'b'},
            ],
          },
          'b': {'narration': 'Fin'},
        },
      });
      expect(graph.unknownTargetIds(), isEmpty);
    });

    test('reports a dangling choice target on a fixed_anchor node', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {
            'choices': [
              {'label': 'x', 'target': 'no_existe'},
            ],
          },
        },
      });
      expect(graph.unknownTargetIds(), {'no_existe'});
    });

    test('reports a dangling fallback exit on a bounded_corridor node', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {
            'type': 'bounded_corridor',
            'goal': 'g',
            'turn_budget': 3,
            'fallback_exit': 'no_existe',
          },
        },
      });
      expect(graph.unknownTargetIds(), {'no_existe'});
    });

    test('reports a dangling exit on a state_hub node', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {
            'type': 'state_hub',
            'exits': [
              {'label': 'Salir', 'target': 'no_existe'},
            ],
          },
        },
      });
      expect(graph.unknownTargetIds(), {'no_existe'});
    });

    test('a resolution node has no outgoing references to check', () {
      final graph = StoryGraph.fromJson({
        'start_node': 'a',
        'nodes': {
          'a': {'type': 'resolution'},
        },
      });
      expect(graph.unknownTargetIds(), isEmpty);
    });
  });
}
