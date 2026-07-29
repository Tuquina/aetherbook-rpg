// prefer_initializing_formals is disabled here: the fields are private and
// Dart forbids private *named* parameters, so `this._field` initializing
// formals are not usable for this public named-argument constructor — same
// reasoning as `game_controller.dart`'s own file-level ignore.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../../../core/authoring/campaign_graph_edits.dart';
import '../../../core/engine/action_resolution.dart';
import '../../../core/engine/apply_state_deltas.dart';
import '../../../core/engine/dice.dart';
import '../../../core/engine/resolve_player_action.dart';
import '../../../core/engine/state_delta.dart';
import '../../../core/narrative/checkable.dart';
import '../../../core/narrative/ending.dart';
import '../../../core/narrative/epilogue_beat.dart';
import '../../../core/narrative/hub_activity.dart';
import '../../../core/narrative/story_choice.dart';
import '../../../core/narrative/story_graph.dart';
import '../../../core/narrative/story_node.dart';
import '../../../core/state/character.dart';
import '../../../core/world/world.dart';

/// How the next checked action resolves in playtest (V2 design prototype
/// §9j "El dado": Al azar / Sale bien / Sale mal / 20) — a debug affordance
/// that has no equivalent in real play, which is exactly why this whole
/// controller is separate from `GameController` and never touches a real
/// `GameSession`.
enum PlaytestDiceMode {
  random,
  forceSuccess,
  forceFailure,
  force20;

  String get label => switch (this) {
        PlaytestDiceMode.random => 'Al azar',
        PlaytestDiceMode.forceSuccess => 'Sale bien',
        PlaytestDiceMode.forceFailure => 'Sale mal',
        PlaytestDiceMode.force20 => '20',
      };
}

/// Drives a playthrough of a campaign draft's [StoryGraph] entirely in
/// memory (V2 design prototype §9j) — reuses the exact same pure `core/
/// engine` use cases real play does (`ResolvePlayerAction`,
/// `ApplyStateDeltas`), just fed a debug [PlaytestDiceMode] instead of real
/// dice, and a throwaway [Character] instead of a persisted one. Nothing
/// here ever calls `GameStateRepositoryPort` or touches a real
/// `GameSession` — the architectural boundary that answers V2_PRODUCT_
/// DECISIONS.md's Decision A objection ("a playtest mode with a debug-
/// capable 'force this dice roll' has no business inside the same binary
/// players use to actually play"): it's real code, but it can never write
/// to a real save.
class CampaignPlaytestController extends ChangeNotifier {
  CampaignPlaytestController({
    required StoryGraph graph,
    required World world,
    required Map<String, String> nodeTitles,
    Dice? dice,
  })  : _graph = graph,
        _world = world,
        _nodeTitles = nodeTitles,
        _resolve = ResolvePlayerAction(dice ?? RandomDice()),
        _apply = ApplyStateDeltas(
          meterDefinitions: world.meterDefinitions,
          resourceFormulas: world.resourceFormulas,
          relationshipMagnitudeCap: world.relationshipMagnitudeCap,
          relationshipMin: world.relationshipMin,
          relationshipMax: world.relationshipMax,
        ),
        flagKeys = (CampaignGraphEdits.allReferencedFlagKeys(graph).toList()..sort()) {
    restart(graph.startNodeId);
  }

  final StoryGraph _graph;
  final World _world;
  final Map<String, String> _nodeTitles;
  final ResolvePlayerAction _resolve;
  final ApplyStateDeltas _apply;

  /// Every flag any gate in the graph checks — the toggle list for "Lo que
  /// ya pasó" (§9j).
  final List<String> flagKeys;

  final Set<String> _usedOnceActivityIds = {};

  PlaytestDiceMode diceMode = PlaytestDiceMode.random;
  late Character character;
  late String currentNodeId;
  late List<String> path;
  int corridorTurnsUsed = 0;
  ActionResolution? lastResolution;
  String? lastResultText;
  bool isEnded = false;
  List<String>? epilogueBeats;

  StoryNode get currentNode => _graph.nodeById(currentNodeId);

  String titleFor(String nodeId) {
    final title = _nodeTitles[nodeId];
    return title != null && title.trim().isNotEmpty ? title : nodeId;
  }

  bool isActivityUsedUp(HubActivity activity) =>
      !activity.repeatable && _usedOnceActivityIds.contains(activity.id);

  /// Every node id in the graph, for the "Empezar la prueba en" picker —
  /// sorted by title so the dropdown reads alphabetically, not by internal
  /// id order.
  List<String> get allNodeIds =>
      _graph.nodes.keys.toList()..sort((a, b) => titleFor(a).compareTo(titleFor(b)));

  /// Resets to a fresh test character and jumps to [nodeId] (defaults to
  /// the graph's real start) — backs both "Empezar de nuevo" and the
  /// "Empezar la prueba en" picker (§9j).
  void restart([String? nodeId]) {
    character = Character(
      name: 'Personaje de prueba',
      level: 1,
      exp: 0,
      attributes: {for (final key in _world.attributeKeys) key: 2},
      resources: {for (final key in _world.resourceFormulas.keys) key: 0},
    );
    currentNodeId = nodeId ?? _graph.startNodeId;
    path = [currentNodeId];
    corridorTurnsUsed = 0;
    _usedOnceActivityIds.clear();
    lastResolution = null;
    lastResultText = null;
    isEnded = false;
    epilogueBeats = null;
    notifyListeners();
  }

  void setDiceMode(PlaytestDiceMode mode) {
    diceMode = mode;
    notifyListeners();
  }

  void adjustAttribute(String key, int delta) {
    final next = (character.attribute(key) + delta).clamp(0, 20);
    character = character.copyWith(attributes: {...character.attributes, key: next});
    notifyListeners();
  }

  void toggleFlag(String key) {
    character = character.copyWith(flags: {...character.flags, key: !character.flag(key)});
    notifyListeners();
  }

  /// The [ActionOutcome] a checked [checkable] resolves to — a real roll in
  /// [PlaytestDiceMode.random] (via the same [ResolvePlayerAction] real play
  /// uses), or the forced band otherwise. An unconditional (no-check)
  /// checkable always "succeeds" for outcome-picking purposes, same
  /// convention `ResolveStoryChoice` uses.
  ActionOutcome _resolveOutcome(Checkable checkable) {
    if (!checkable.requiresCheck) return ActionOutcome.success;
    if (diceMode == PlaytestDiceMode.random) {
      final resolution = _resolve(
        attributeKey: checkable.checkAttribute!,
        attribute: character.attribute(checkable.checkAttribute!),
        difficulty: checkable.checkDifficulty!,
        criticalMargin: _world.criticalMargin,
      );
      lastResolution = resolution;
      return resolution.outcome;
    }
    lastResolution = null;
    return switch (diceMode) {
      PlaytestDiceMode.forceSuccess => ActionOutcome.success,
      PlaytestDiceMode.forceFailure => ActionOutcome.failure,
      PlaytestDiceMode.force20 => ActionOutcome.criticalSuccess,
      PlaytestDiceMode.random => throw StateError('unreachable'),
    };
  }

  /// Available choices/exits for [currentNode] — gate-filtered against the
  /// test character, same `.isAvailableTo`/`.availableX` calls real play
  /// uses.
  List<StoryChoice> get availableActions => switch (currentNode) {
        FixedAnchorNode(:final choices) =>
          [for (final c in choices) if (c.isAvailableTo(character)) c],
        BoundedCorridorNode(:final choices) =>
          [for (final c in choices) if (c.isAvailableTo(character)) c],
        StateHubNode(:final exits) => [for (final e in exits) if (e.isAvailableTo(character)) e],
        ResolutionNode() => const [],
      };

  List<HubActivity> get availableActivities {
    final node = currentNode;
    if (node is! StateHubNode) return const [];
    return node.availableActivities(character);
  }

  List<Ending> get availableEndings {
    final node = currentNode;
    if (node is! ResolutionNode) return const [];
    return node.availableEndings(character);
  }

  void chooseAction(StoryChoice choice) {
    final outcome = _resolveOutcome(choice);
    final resolved = choice.outcomeFor(outcome);
    character = _apply(character, resolved.effects).character;
    lastResultText = resolved.resultText;
    _advanceTo(resolved.targetNodeId ?? choice.targetNodeId);
  }

  void chooseActivity(HubActivity activity) {
    final outcome = _resolveOutcome(activity);
    final resolved = activity.outcomeFor(outcome);
    character = _apply(character, resolved.effects).character;
    lastResultText = resolved.resultText;
    if (!activity.repeatable) _usedOnceActivityIds.add(activity.id);
    notifyListeners();
  }

  /// Uses the corridor's declared fallback exit — the same "nadie puede
  /// quedarse atrapado en un tramo" guarantee real play enforces once the
  /// turn budget runs out, exposed here as a manual button since playtest
  /// never simulates real freeform turns.
  void useFallbackExit() {
    final node = currentNode;
    if (node is! BoundedCorridorNode) return;
    _advanceTo(node.fallbackExitNodeId);
  }

  /// Resolves [ending] with the exact same formula `GameController.
  /// chooseEnding` uses: `world.primaryAttribute` at `world.criticalMargin`
  /// against `ending.difficultyFor(character)`, success/cost reveals joined
  /// as the result text, and — when declared — advances to
  /// `ResolutionNode.epilogueNodeId` and assembles its beats.
  void chooseEnding(Ending ending) {
    final resolution = diceMode == PlaytestDiceMode.random
        ? _resolve(
            attributeKey: _world.primaryAttribute,
            attribute: character.attribute(_world.primaryAttribute),
            difficulty: ending.difficultyFor(character),
            criticalMargin: _world.criticalMargin,
          )
        : null;
    lastResolution = resolution;
    final succeeded = resolution?.isSuccess ??
        (diceMode == PlaytestDiceMode.forceSuccess || diceMode == PlaytestDiceMode.force20);

    final resolvedEndingId = succeeded ? ending.id : ending.failureEndingIdFor(character);
    final reveals = succeeded
        ? [...ending.successReveals, ...ending.costReveals]
        : [
            ...ending.costReveals,
            if (ending.failureCostOptions.isNotEmpty) ending.failureCostOptions.first,
          ];
    lastResultText = reveals.isEmpty ? ending.visibleChoice : reveals.join(' ');

    final node = currentNode as ResolutionNode;
    final effects = <StateDelta>[
      StateDelta(type: StateDeltaType.flag, key: 'ending_$resolvedEndingId', value: true),
    ];
    for (final rule in node.finalTechniqueRules) {
      if (rule.isSatisfiedBy(character)) {
        effects.add(StateDelta(type: StateDeltaType.varSet, key: 'final_technique_id', value: rule.techniqueId));
        break;
      }
    }
    character = _apply(character, effects).character;

    final epilogueId = node.epilogueNodeId;
    if (epilogueId != null && _graph.nodes.containsKey(epilogueId)) {
      currentNodeId = epilogueId;
      path = [...path, epilogueId];
      final epilogueNode = _graph.nodeById(epilogueId);
      epilogueBeats = epilogueNode is ResolutionNode
          ? assembleEpilogueBeats(epilogueNode.epilogueBeats, character)
          : const [];
    } else {
      isEnded = true;
    }
    notifyListeners();
  }

  void _advanceTo(String targetNodeId) {
    if (targetNodeId.isNotEmpty && _graph.nodes.containsKey(targetNodeId)) {
      currentNodeId = targetNodeId;
      path = [...path, targetNodeId];
      corridorTurnsUsed = 0;
    }
    notifyListeners();
  }
}
