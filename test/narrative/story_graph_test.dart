import 'package:aetherbook/core/narrative/story_graph.dart';
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
      expect(graph.startNode.narration, 'Inicio');
      expect(graph.nodeById('beat_2').narration, 'Fin');
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

      final fromA = graph.nodeById('a').choices.single.targetNodeId;
      final fromB = graph.nodeById('b').choices.single.targetNodeId;
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
}
