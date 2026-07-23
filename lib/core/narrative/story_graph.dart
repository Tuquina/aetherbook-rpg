import 'story_node.dart';

/// A directed graph of [StoryNode]s for curated/hybrid campaigns (GDD §4.1,
/// §10). Loaded from a declarative JSON file, never hardcoded (CLAUDE.md §8).
/// Deliberately a graph, not a tree: different choices can converge back on
/// the same node.
class StoryGraph {
  const StoryGraph({required this.startNodeId, required this.nodes});

  final String startNodeId;
  final Map<String, StoryNode> nodes;

  StoryNode get startNode => nodeById(startNodeId);

  StoryNode nodeById(String id) {
    final node = nodes[id];
    if (node == null) {
      throw ArgumentError('unknown story node: $id');
    }
    return node;
  }

  /// Every node id referenced by a choice/exit/fallback exit anywhere in the
  /// graph that isn't actually declared in [nodes] — referential integrity
  /// for a large, hand-authored graph (campaign-bible §22.1: "desde todo
  /// nodo existe una ruta válida..."). Pure and generic, not tied to any one
  /// campaign's node ids.
  Set<String> unknownTargetIds() {
    final referenced = <String>{};
    for (final node in nodes.values) {
      switch (node) {
        case FixedAnchorNode(:final choices):
          referenced.addAll(choices.map((c) => c.targetNodeId));
        case BoundedCorridorNode(:final choices, :final fallbackExitNodeId):
          referenced.addAll(choices.map((c) => c.targetNodeId));
          referenced.add(fallbackExitNodeId);
        case StateHubNode(:final exits):
          referenced.addAll(exits.map((e) => e.targetNodeId));
        case ResolutionNode():
          break;
      }
    }
    return referenced.difference(nodes.keys.toSet());
  }

  factory StoryGraph.fromJson(Map<String, dynamic> json) {
    final nodesJson = (json['nodes'] as Map).cast<String, dynamic>();
    return StoryGraph(
      startNodeId: json['start_node'] as String,
      nodes: {
        for (final entry in nodesJson.entries)
          entry.key: StoryNode.fromJson(
            entry.key,
            (entry.value as Map).cast<String, dynamic>(),
          ),
      },
    );
  }
}
