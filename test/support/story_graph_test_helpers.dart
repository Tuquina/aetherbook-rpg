// Shared structural validators for a campaign's real content JSON — used by
// both the hybrid (xianxia_lianshu) and curated (curated_zombie_01) content
// tests so the pattern lives in one place instead of being copy-pasted per
// campaign.
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/hub_activity.dart';
import 'package:aetherbook/core/narrative/story_choice.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';

/// Every node id reachable from [graph]'s start node, following choices,
/// hub exits and corridor fallback exits — a resolution node is terminal.
/// A target the graph doesn't declare (a chapter not written yet, or a
/// genuine typo — `unknownTargetIds()` is the dedicated check for telling
/// those apart) is left out rather than crashing the walk.
Set<String> reachableFrom(StoryGraph graph) {
  final visited = <String>{};
  final queue = [graph.startNodeId];
  while (queue.isNotEmpty) {
    final id = queue.removeLast();
    if (!graph.nodes.containsKey(id)) continue;
    if (!visited.add(id)) continue;
    final node = graph.nodeById(id);
    final next = switch (node) {
      FixedAnchorNode(:final choices) => choices.map((c) => c.targetNodeId),
      BoundedCorridorNode(:final choices, :final fallbackExitNodeId) => [
          ...choices.map((c) => c.targetNodeId),
          fallbackExitNodeId,
        ],
      StateHubNode(:final exits) => exits.map((e) => e.targetNodeId),
      ResolutionNode() => const <String>[],
    };
    queue.addAll(next);
  }
  return visited;
}

/// Every flag key set `true` by any effect anywhere in the graph — across a
/// choice/activity's base effects and every one of its `onSuccess`/
/// `onCriticalSuccess`/`onFailure` branches. Used to catch a milestone flag
/// (or any other flag a Gate depends on) that's declared but never actually
/// reachable through the content.
Set<String> allTrueFlagKeysSet(StoryGraph graph) {
  final keys = <String>{};
  void collect(Iterable<StateDelta> effects) {
    for (final delta in effects) {
      if (delta.type == StateDeltaType.flag && delta.value == true) {
        keys.add(delta.key);
      }
    }
  }

  void collectChoice(StoryChoice choice) {
    collect(choice.effects);
    if (choice.onSuccess != null) collect(choice.onSuccess!.effects);
    if (choice.onCriticalSuccess != null) {
      collect(choice.onCriticalSuccess!.effects);
    }
    if (choice.onFailure != null) collect(choice.onFailure!.effects);
  }

  void collectActivity(HubActivity activity) {
    collect(activity.effects);
    if (activity.onSuccess != null) collect(activity.onSuccess!.effects);
    if (activity.onCriticalSuccess != null) {
      collect(activity.onCriticalSuccess!.effects);
    }
    if (activity.onFailure != null) collect(activity.onFailure!.effects);
  }

  for (final node in graph.nodes.values) {
    switch (node) {
      case FixedAnchorNode(:final choices):
        choices.forEach(collectChoice);
      case BoundedCorridorNode(:final choices):
        choices.forEach(collectChoice);
      case StateHubNode(:final activities, :final exits):
        activities.forEach(collectActivity);
        exits.forEach(collectChoice);
      case ResolutionNode():
        break;
    }
  }
  return keys;
}

/// For a curated, AI-free world (`ai_runtime_required: false`): every
/// checked choice/activity outcome branch that's actually reachable must
/// carry its own literal `resultText`, since `GameController` never calls
/// `NarratorPort` for this world — a missing one would render as blank
/// narration instead of falling back to AI (campaign-bible §25.10). Returns
/// `"<nodeId>.<choiceLabel>.<band>"` for every offending branch.
List<String> choicesMissingResultText(StoryGraph graph) {
  final missing = <String>[];

  void checkOutcome(String nodeId, String label, String band, ChoiceOutcome? outcome) {
    if (outcome == null) return;
    if (outcome.resultText == null || outcome.resultText!.trim().isEmpty) {
      missing.add('$nodeId.$label.$band');
    }
  }

  void checkChoice(String nodeId, StoryChoice choice) {
    if (choice.requiresCheck) {
      checkOutcome(nodeId, choice.label, 'onSuccess', choice.onSuccess);
      checkOutcome(nodeId, choice.label, 'onFailure', choice.onFailure);
      // onCriticalSuccess is allowed to fall back to onSuccess silently.
    } else {
      // An unconditional choice always resolves to onSuccess if declared,
      // else its own top-level resultText (StoryChoice.outcomeFor's `base`).
      final text = choice.onSuccess?.resultText ?? choice.resultText;
      if (text == null || text.trim().isEmpty) {
        missing.add('$nodeId.${choice.label}.unconditional');
      }
    }
  }

  void checkActivity(String nodeId, HubActivity activity) {
    if (activity.requiresCheck) {
      checkOutcome(nodeId, activity.label, 'onSuccess', activity.onSuccess);
      checkOutcome(nodeId, activity.label, 'onFailure', activity.onFailure);
    } else {
      final text = activity.onSuccess?.resultText ?? activity.resultText;
      if (text == null || text.trim().isEmpty) {
        missing.add('$nodeId.${activity.label}.unconditional');
      }
    }
  }

  for (final id in reachableFrom(graph)) {
    final node = graph.nodeById(id);
    switch (node) {
      case FixedAnchorNode(:final choices):
        for (final c in choices) {
          checkChoice(id, c);
        }
      case BoundedCorridorNode(:final choices):
        for (final c in choices) {
          checkChoice(id, c);
        }
      case StateHubNode(:final activities, :final exits):
        for (final a in activities) {
          checkActivity(id, a);
        }
        for (final e in exits) {
          checkChoice(id, e);
        }
      case ResolutionNode():
        break;
    }
  }
  return missing;
}
