import '../narrative/gate.dart';
import '../narrative/story_choice.dart';
import '../narrative/story_graph.dart';
import '../narrative/story_node.dart';

/// The 4 node types an author can add from the editor's "Añadir" sidebar
/// (V2 design prototype §9a), mirroring the `StoryNode` sealed hierarchy
/// one-to-one.
enum NodeKind { fixedAnchor, boundedCorridor, stateHub, resolution }

/// Pure graph-editing operations for the campaign editor (V2 design
/// prototype §9a-9j) — kept in `core/` and Flutter-free, same reasoning as
/// every other engine use case (CLAUDE.md §2.2/§5): the editor's map screen
/// stays a thin caller, and every rule here is unit-testable without
/// widgets. `StoryNode`/`StoryChoice`/`StoryGraph` themselves have no
/// `copyWith` (they were never mutated after being loaded from static
/// content before this feature existed) — these functions are that missing
/// "reconstruct with one field changed" capability, added here instead of
/// on the domain classes themselves so the read-only game engine keeps
/// depending on nothing new.
abstract final class CampaignGraphEdits {
  /// A freshly created, minimally-valid node of [kind] — the sidebar's
  /// "Añadir" buttons call this, then the author fills in real content via
  /// the node inspector.
  static StoryNode blankNode(String id, NodeKind kind) => switch (kind) {
        NodeKind.fixedAnchor => FixedAnchorNode(id: id),
        NodeKind.boundedCorridor => BoundedCorridorNode(
            id: id,
            goal: '',
            turnBudget: 3,
            fallbackExitNodeId: '',
          ),
        NodeKind.stateHub => StateHubNode(id: id),
        NodeKind.resolution => ResolutionNode(id: id),
      };

  /// Upserts [node] into [graph] by id.
  static StoryGraph withNode(StoryGraph graph, StoryNode node) => StoryGraph(
        startNodeId: graph.startNodeId,
        nodes: {...graph.nodes, node.id: node},
      );

  /// Removes node [id] from [graph]. If it was the start node, the graph is
  /// left with an empty `startNodeId` — the pre-publish checklist (§9i)
  /// surfaces "no hay escena de inicio" rather than this silently picking
  /// an arbitrary replacement.
  static StoryGraph withoutNode(StoryGraph graph, String id) {
    final nodes = {...graph.nodes}..remove(id);
    return StoryGraph(
      startNodeId: graph.startNodeId == id ? '' : graph.startNodeId,
      nodes: nodes,
    );
  }

  static StoryGraph withStartNode(StoryGraph graph, String id) =>
      StoryGraph(startNodeId: id, nodes: graph.nodes);

  /// A bare, unconditional, unchecked edge — the editor's Stage-2-level
  /// "connect two nodes" primitive. Gates/checks/outcome-band authoring is
  /// the node/choice editors' job (§9b/§9c/§9g/§9h), layered on top of this
  /// by editing the resulting [StoryChoice] further.
  static StoryChoice blankChoice({required String label, required String targetNodeId}) =>
      StoryChoice(label: label, targetNodeId: targetNodeId, gate: const AlwaysGate());

  /// Whether [node] can hold outgoing choices/exits at all — a
  /// `ResolutionNode` is terminal (its `endings` are authored separately,
  /// §9c).
  static bool supportsChoices(StoryNode node) => node is! ResolutionNode;

  /// [node] with [choice] appended to its choices ([FixedAnchorNode]/
  /// [BoundedCorridorNode]) or exits ([StateHubNode]). Throws for a
  /// [ResolutionNode] — check [supportsChoices] first.
  static StoryNode withAddedChoice(StoryNode node, StoryChoice choice) {
    return switch (node) {
      FixedAnchorNode(:final choices) =>
        _copyFixedAnchor(node, choices: [...choices, choice]),
      BoundedCorridorNode(:final choices) =>
        _copyBoundedCorridor(node, choices: [...choices, choice]),
      StateHubNode(:final exits) => _copyStateHub(node, exits: [...exits, choice]),
      ResolutionNode() =>
        throw ArgumentError('a ResolutionNode has no choices/exits — see supportsChoices'),
    };
  }

  /// [node] with the choice/exit at [index] replaced by [choice] — used when
  /// editing an existing choice in place, so its position in the list
  /// doesn't shift the way remove-then-add would.
  static StoryNode withChoiceReplacedAt(StoryNode node, int index, StoryChoice choice) {
    return switch (node) {
      FixedAnchorNode(:final choices) =>
        _copyFixedAnchor(node, choices: [...choices]..[index] = choice),
      BoundedCorridorNode(:final choices) =>
        _copyBoundedCorridor(node, choices: [...choices]..[index] = choice),
      StateHubNode(:final exits) =>
        _copyStateHub(node, exits: [...exits]..[index] = choice),
      ResolutionNode() =>
        throw ArgumentError('a ResolutionNode has no choices/exits — see supportsChoices'),
    };
  }

  /// [node] with the choice/exit at [index] removed.
  static StoryNode withRemovedChoiceAt(StoryNode node, int index) {
    return switch (node) {
      FixedAnchorNode(:final choices) => _copyFixedAnchor(
          node, choices: [...choices]..removeAt(index)),
      BoundedCorridorNode(:final choices) => _copyBoundedCorridor(
          node, choices: [...choices]..removeAt(index)),
      StateHubNode(:final exits) =>
        _copyStateHub(node, exits: [...exits]..removeAt(index)),
      ResolutionNode() =>
        throw ArgumentError('a ResolutionNode has no choices/exits — see supportsChoices'),
    };
  }

  /// [node] with its display-relevant body text replaced — [FixedAnchorNode]
  /// .narration or [BoundedCorridorNode].goal. A no-op passthrough for
  /// [StateHubNode]/[ResolutionNode], which have no single body-text field.
  static StoryNode withBodyText(StoryNode node, String text) {
    return switch (node) {
      FixedAnchorNode() => _copyFixedAnchor(node, narration: text),
      BoundedCorridorNode() => _copyBoundedCorridor(node, goal: text),
      StateHubNode() => node,
      ResolutionNode() => _copyResolution(node, narration: text),
    };
  }

  /// [node] with its fixed reveals replaced — [FixedAnchorNode.fixedReveals]
  /// (§9a's "El narrador debe decir"). A no-op for any other node type.
  static StoryNode withFixedReveals(StoryNode node, List<String> reveals) {
    if (node is! FixedAnchorNode) return node;
    return _copyFixedAnchor(node, fixedReveals: reveals);
  }

  /// [node] with its forbidden reveals replaced —
  /// [FixedAnchorNode.forbiddenReveals] (§9a's "Todavía no puede revelar").
  /// A no-op for any other node type.
  static StoryNode withForbiddenReveals(StoryNode node, List<String> reveals) {
    if (node is! FixedAnchorNode) return node;
    return _copyFixedAnchor(node, forbiddenReveals: reveals);
  }

  static FixedAnchorNode _copyFixedAnchor(
    FixedAnchorNode node, {
    String? narration,
    List<StoryChoice>? choices,
    List<String>? fixedReveals,
    List<String>? forbiddenReveals,
  }) =>
      FixedAnchorNode(
        id: node.id,
        narration: narration ?? node.narration,
        choices: choices ?? node.choices,
        fixedReveals: fixedReveals ?? node.fixedReveals,
        forbiddenReveals: forbiddenReveals ?? node.forbiddenReveals,
        extendedConflict: node.extendedConflict,
        conditionalInserts: node.conditionalInserts,
        codexReveals: node.codexReveals,
      );

  static BoundedCorridorNode _copyBoundedCorridor(
    BoundedCorridorNode node, {
    String? goal,
    int? turnBudget,
    String? fallbackExitNodeId,
    List<StoryChoice>? choices,
  }) =>
      BoundedCorridorNode(
        id: node.id,
        goal: goal ?? node.goal,
        turnBudget: turnBudget ?? node.turnBudget,
        fallbackExitNodeId: fallbackExitNodeId ?? node.fallbackExitNodeId,
        allowedLocations: node.allowedLocations,
        allowedNpcs: node.allowedNpcs,
        allowedObstacles: node.allowedObstacles,
        forbiddenReveals: node.forbiddenReveals,
        choices: choices ?? node.choices,
        codexReveals: node.codexReveals,
      );

  static StateHubNode _copyStateHub(StateHubNode node, {List<StoryChoice>? exits}) =>
      StateHubNode(
        id: node.id,
        activities: node.activities,
        exits: exits ?? node.exits,
        codexReveals: node.codexReveals,
      );

  static ResolutionNode _copyResolution(ResolutionNode node, {String? narration}) =>
      ResolutionNode(
        id: node.id,
        narration: narration ?? node.narration,
        endings: node.endings,
        epilogueBeats: node.epilogueBeats,
        finalTechniqueRules: node.finalTechniqueRules,
        epilogueNodeId: node.epilogueNodeId,
        codexReveals: node.codexReveals,
      );

  /// Every choice/exit target id [node] points to, for the map's connection
  /// lines/summaries — [BoundedCorridorNode.fallbackExitNodeId] included.
  static List<String> outgoingTargets(StoryNode node) => switch (node) {
        FixedAnchorNode(:final choices) => [for (final c in choices) c.targetNodeId],
        BoundedCorridorNode(:final choices, :final fallbackExitNodeId) => [
            for (final c in choices) c.targetNodeId,
            if (fallbackExitNodeId.isNotEmpty) fallbackExitNodeId,
          ],
        StateHubNode(:final exits) => [for (final e in exits) e.targetNodeId],
        ResolutionNode() => const [],
      };

  /// [gate] decomposed into a flat AND-list for the editor's gate-condition
  /// list (§9b/§9c/§9g/§9h "Sólo aparece si…") — the inverse of [buildGate].
  /// `AlwaysGate` flattens to `[]`; an `AllOfGate` flattens to its direct
  /// children (one level only — a nested `AllOfGate` inside another isn't
  /// something this editor ever produces, so it's kept as a single opaque
  /// entry rather than recursively flattened); anything else (including
  /// `AnyOfGate`, which this simple AND-only editor can't represent) is a
  /// single opaque entry, shown read-only via `CampaignSummaries.gate`.
  static List<Gate> flattenGate(Gate gate) => switch (gate) {
        AlwaysGate() => const [],
        AllOfGate(:final gates) => gates,
        _ => [gate],
      };

  /// The inverse of [flattenGate]: `[]` -> `AlwaysGate`, one condition ->
  /// itself, more than one -> `AllOfGate`.
  static Gate buildGate(List<Gate> conditions) => switch (conditions.length) {
        0 => const AlwaysGate(),
        1 => conditions.single,
        _ => AllOfGate(conditions),
      };

  /// Groups every node in [graph] by its BFS distance from `startNodeId`
  /// (the map canvas' column layout, §9a) — nodes unreachable from the
  /// start (including when there's no start node at all) land in a final
  /// bucket keyed [unreachableDepth], one past the deepest real layer, so a
  /// caller can render them as a visually separate "cabo suelto" column.
  static Map<int, List<String>> bfsLayers(StoryGraph graph) {
    final depths = <String, int>{};
    if (graph.nodes.containsKey(graph.startNodeId)) {
      final queue = [graph.startNodeId];
      depths[graph.startNodeId] = 0;
      var i = 0;
      while (i < queue.length) {
        final current = queue[i++];
        final node = graph.nodes[current];
        if (node == null) continue;
        for (final target in outgoingTargets(node)) {
          if (depths.containsKey(target) || !graph.nodes.containsKey(target)) continue;
          depths[target] = depths[current]! + 1;
          queue.add(target);
        }
      }
    }
    final maxDepth = depths.values.fold(0, (a, b) => a > b ? a : b);
    final unreachableDepth = maxDepth + 1;
    final layers = <int, List<String>>{};
    for (final id in graph.nodes.keys) {
      final depth = depths[id] ?? unreachableDepth;
      (layers[depth] ??= []).add(id);
    }
    return layers;
  }
}
