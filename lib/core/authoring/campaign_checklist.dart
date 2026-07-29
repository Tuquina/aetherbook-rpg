import '../engine/state_delta.dart';
import '../narrative/gate.dart';
import '../narrative/hub_activity.dart';
import '../narrative/story_choice.dart';
import '../narrative/story_graph.dart';
import '../narrative/story_node.dart';
import 'campaign_draft.dart';
import 'campaign_graph_edits.dart';

/// One thing the pre-publish checklist (V2 design prototype §9i) found —
/// either a [blocking] problem ("un lector se quedaría sin saber qué pasa")
/// or something merely worth a look. [nodeId], when set, is where tapping
/// the issue should jump the author.
class ChecklistIssue {
  const ChecklistIssue({
    required this.blocking,
    required this.message,
    this.detail,
    this.nodeId,
  });

  final bool blocking;
  final String message;
  final String? detail;
  final String? nodeId;
}

/// Computes [ChecklistIssue]s for a [CampaignDraft] (§9i). Every check here
/// is real and structural — reachability, dangling references, missing
/// text a stated contract requires — not a heuristic pretending to be one.
/// A few of the mockup's advisory checks (an unlikely dice streak, a
/// too-short critical path vs. the declared duration) would need genuine
/// statistical/simulation work this pass doesn't attempt; only the
/// never-settable-flag check below is included as a first, real advisory
/// signal, alongside every blocking check.
abstract final class CampaignChecklist {
  static List<ChecklistIssue> blocking(CampaignDraft draft) {
    final graph = draft.graph;
    final issues = <ChecklistIssue>[];

    if (draft.title.trim().isEmpty || draft.synopsis.trim().isEmpty) {
      issues.add(const ChecklistIssue(
        blocking: true,
        message: 'Falta el título o la sinopsis',
        detail: 'Se completan en «Portada e información».',
      ));
    }

    if (graph.nodes.isEmpty) {
      issues.add(const ChecklistIssue(
        blocking: true,
        message: 'La historia todavía no tiene ninguna escena',
      ));
      return issues;
    }

    if (!graph.nodes.containsKey(graph.startNodeId)) {
      issues.add(const ChecklistIssue(
        blocking: true,
        message: 'No hay ninguna escena marcada como inicio',
      ));
    }

    if (_endingCount(draft) == 0) {
      issues.add(const ChecklistIssue(
        blocking: true,
        message: 'La historia no tiene ningún final todavía',
      ));
    }

    for (final id in graph.unknownTargetIds()) {
      issues.add(ChecklistIssue(
        blocking: true,
        message: 'Hay una opción que lleva a «$id», una escena que no existe',
        detail: 'Buscá la escena de origen y corregí o creá el destino.',
      ));
    }

    final reachable = _reachableFromStart(graph);
    for (final id in graph.nodes.keys) {
      if (!reachable.contains(id)) {
        issues.add(ChecklistIssue(
          blocking: true,
          message: '«${draft.titleForNode(id)}» no se puede alcanzar desde el inicio',
          nodeId: id,
        ));
      }
    }

    if (reachable.isNotEmpty) {
      final leadsToEnding = _nodesLeadingToAnEnding(graph);
      for (final id in reachable) {
        final node = graph.nodes[id];
        if (node == null || node is ResolutionNode) continue;
        if (!leadsToEnding.contains(id)) {
          issues.add(ChecklistIssue(
            blocking: true,
            message: 'Desde «${draft.titleForNode(id)}» no se puede llegar a ningún final',
            nodeId: id,
          ));
        }
      }
    }

    if (!draft.aiRuntimeRequired) {
      issues.addAll(_missingResultTextIssues(draft));
    }

    return issues;
  }

  static List<ChecklistIssue> advisory(CampaignDraft draft) {
    final issues = <ChecklistIssue>[];
    final everSetFlags = _everSetFlagKeys(draft.graph);
    for (final node in draft.graph.nodes.values) {
      if (node is! ResolutionNode) continue;
      for (final ending in node.endings) {
        final required = _referencedFlagKeys(ending.hardRequirement);
        final neverSet = required.difference(everSetFlags);
        if (neverSet.isNotEmpty) {
          issues.add(ChecklistIssue(
            blocking: false,
            message: '«${ending.visibleChoice.isEmpty ? ending.id : ending.visibleChoice}» '
                'puede no ofrecerse nunca',
            detail: 'Pide la bandera "${neverSet.first}", que ninguna escena activa todavía.',
            nodeId: node.id,
          ));
        }
      }
    }
    return issues;
  }

  static int _endingCount(CampaignDraft draft) {
    var count = 0;
    for (final node in draft.graph.nodes.values) {
      if (node is ResolutionNode) count += node.endings.length;
    }
    return count;
  }

  static Set<String> _reachableFromStart(StoryGraph graph) {
    if (!graph.nodes.containsKey(graph.startNodeId)) return const {};
    final visited = <String>{graph.startNodeId};
    final queue = [graph.startNodeId];
    var i = 0;
    while (i < queue.length) {
      final current = queue[i++];
      final node = graph.nodes[current];
      if (node == null) continue;
      for (final target in CampaignGraphEdits.outgoingTargets(node)) {
        if (!graph.nodes.containsKey(target)) continue;
        if (visited.add(target)) queue.add(target);
      }
    }
    return visited;
  }

  static Set<String> _nodesLeadingToAnEnding(StoryGraph graph) {
    final reverseEdges = <String, List<String>>{};
    for (final node in graph.nodes.values) {
      for (final target in CampaignGraphEdits.outgoingTargets(node)) {
        (reverseEdges[target] ??= []).add(node.id);
      }
    }
    final endingNodeIds = [
      for (final node in graph.nodes.values)
        if (node is ResolutionNode && node.endings.isNotEmpty) node.id,
    ];
    final result = <String>{...endingNodeIds};
    final queue = [...endingNodeIds];
    var i = 0;
    while (i < queue.length) {
      final current = queue[i++];
      for (final predecessor in reverseEdges[current] ?? const <String>[]) {
        if (result.add(predecessor)) queue.add(predecessor);
      }
    }
    return result;
  }

  static List<ChecklistIssue> _missingResultTextIssues(CampaignDraft draft) {
    final issues = <ChecklistIssue>[];
    for (final node in draft.graph.nodes.values) {
      final choices = switch (node) {
        FixedAnchorNode(:final choices) => choices,
        BoundedCorridorNode(:final choices) => choices,
        StateHubNode(:final exits, :final activities) => [
            ...exits,
            ..._activityChoices(activities),
          ],
        ResolutionNode() => const <StoryChoice>[],
      };
      for (final choice in choices) {
        if (choice.checkAttribute == null) {
          if ((choice.resultText ?? '').trim().isEmpty) {
            issues.add(ChecklistIssue(
              blocking: true,
              message: '«${choice.label}» no tiene texto — hace falta para jugar sin IA',
              nodeId: node.id,
            ));
          }
        } else {
          if ((choice.onSuccess?.resultText ?? '').trim().isEmpty) {
            issues.add(ChecklistIssue(
              blocking: true,
              message: '«${choice.label}» no tiene texto en «sale bien»',
              nodeId: node.id,
            ));
          }
          if ((choice.onFailure?.resultText ?? '').trim().isEmpty) {
            issues.add(ChecklistIssue(
              blocking: true,
              message: '«${choice.label}» no tiene texto en «sale mal»',
              nodeId: node.id,
            ));
          }
        }
      }
    }
    return issues;
  }

  /// [activities] reshaped as [StoryChoice]s purely so the reachability/
  /// missing-text checks above can treat a hub's activities and a scene's
  /// choices uniformly — never persisted, never leaves this file.
  static List<StoryChoice> _activityChoices(List<HubActivity> activities) => [
        for (final a in activities)
          StoryChoice(
            label: a.label,
            targetNodeId: '',
            resultText: a.resultText,
            checkAttribute: a.checkAttribute,
            checkDifficulty: a.checkDifficulty,
            onSuccess: a.onSuccess,
            onFailure: a.onFailure,
          ),
      ];

  static Set<String> _referencedFlagKeys(Gate gate) => switch (gate) {
        FlagGate(:final key) => {key},
        AllOfGate(:final gates) => {for (final g in gates) ..._referencedFlagKeys(g)},
        AnyOfGate(:final gates) => {for (final g in gates) ..._referencedFlagKeys(g)},
        _ => const {},
      };

  static Set<String> _everSetFlagKeys(StoryGraph graph) {
    final keys = <String>{};
    void collectFrom(List<StoryChoice> choices) {
      for (final choice in choices) {
        for (final effects in [
          choice.effects,
          choice.onSuccess?.effects ?? const [],
          choice.onCriticalSuccess?.effects ?? const [],
          choice.onFailure?.effects ?? const [],
        ]) {
          for (final effect in effects) {
            if (effect.type == StateDeltaType.flag) keys.add(effect.key);
          }
        }
      }
    }

    for (final node in graph.nodes.values) {
      switch (node) {
        case FixedAnchorNode(:final choices):
          collectFrom(choices);
        case BoundedCorridorNode(:final choices):
          collectFrom(choices);
        case StateHubNode(:final exits, :final activities):
          collectFrom(exits);
          collectFrom(_activityChoices(activities));
        case ResolutionNode():
          break;
      }
    }
    return keys;
  }
}
