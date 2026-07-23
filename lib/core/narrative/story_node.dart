import '../state/character.dart';
import 'ending.dart';
import 'epilogue_beat.dart';
import 'extended_conflict.dart';
import 'final_technique_rule.dart';
import 'hub_activity.dart';
import 'story_choice.dart';

/// The four node types a hybrid campaign is built from (campaign-bible
/// §9.1). Modeled as a sealed hierarchy — rather than one flat class with a
/// pile of nullable fields — because each type carries genuinely different
/// data and hands genuinely different responsibilities to the human author
/// vs. the AI narrator:
///
/// | Type               | Human authors...                  | AI narrates...            |
/// |---------------------|------------------------------------|----------------------------|
/// | [FixedAnchorNode]    | facts, entry, reveal, exit         | reactive prose, continuity |
/// | [BoundedCorridorNode]| goal, limits, turn budget, exit    | obstacles, dialogue        |
/// | [StateHubNode]       | activities, rewards, the clock     | order, mood, transitions   |
/// | [ResolutionNode]     | exact ending conditions and costs  | climax prose, epilogue     |
///
/// "Un corredor nunca puede generar otro hito, antagonista principal, objeto
/// legendario ni solución final" — that constraint is enforced by *not
/// giving corridors those things to generate*, not by a runtime check.
sealed class StoryNode {
  const StoryNode({required this.id});

  final String id;

  factory StoryNode.fromJson(String id, Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'fixed_anchor';
    return switch (type) {
      'bounded_corridor' => BoundedCorridorNode.fromJson(id, json),
      'state_hub' => StateHubNode.fromJson(id, json),
      'resolution' => ResolutionNode.fromJson(id, json),
      _ => FixedAnchorNode.fromJson(id, json),
    };
  }
}

/// Authored, guaranteed-quality prose with a small set of curated choices
/// (§9.1: "Hechos, entrada, revelación, opciones críticas y salida"). The AI
/// only narrates reactively here — it doesn't invent plot.
final class FixedAnchorNode extends StoryNode {
  const FixedAnchorNode({
    required super.id,
    this.narration = '',
    this.choices = const [],
    this.fixedReveals = const [],
    this.forbiddenReveals = const [],
    this.extendedConflict,
  });

  final String narration;
  final List<StoryChoice> choices;

  /// Facts the narrator must reveal at this node (§19.1 `fixed_reveals`).
  final List<String> fixedReveals;

  /// Facts the narrator must never reveal here yet (§19.1 `forbidden_reveals`).
  final List<String> forbiddenReveals;

  /// When set, this set-piece resolves as an extended conflict (§6.12) —
  /// e.g. "Coro en el campanario" — instead of a single check.
  final ExtendedConflict? extendedConflict;

  /// The choices whose gate is currently satisfied, in authored order.
  List<StoryChoice> availableChoices(Character character) => [
        for (final choice in choices)
          if (choice.isAvailableTo(character)) choice,
      ];

  factory FixedAnchorNode.fromJson(String id, Map<String, dynamic> json) {
    return FixedAnchorNode(
      id: id,
      narration: json['narration'] as String? ?? '',
      choices: _choicesFromJson(json['choices']),
      fixedReveals: _stringList(json['fixed_reveals']),
      forbiddenReveals: _stringList(json['forbidden_reveals']),
      extendedConflict: json['extended_conflict'] is Map
          ? ExtendedConflict.fromJson(
              (json['extended_conflict'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

/// A goal-bounded stretch of freeform play (§9.1, §18.8): the human sets the
/// objective, the turn budget and the forced exit; the AI improvises
/// obstacles and dialogue strictly within those limits.
final class BoundedCorridorNode extends StoryNode {
  const BoundedCorridorNode({
    required super.id,
    required this.goal,
    required this.turnBudget,
    required this.fallbackExitNodeId,
    this.allowedLocations = const [],
    this.allowedNpcs = const [],
    this.allowedObstacles = const [],
    this.forbiddenReveals = const [],
    this.choices = const [],
  });

  /// The single objective the AI is allowed to pursue here.
  final String goal;

  /// Max turns before the corridor forces an exit (§18.8 `turn_budget`).
  final int turnBudget;

  /// Where the graph moves if the budget runs out before an explicit exit
  /// choice is taken (§18.8 `fallback_exit`).
  final String fallbackExitNodeId;

  final List<String> allowedLocations;
  final List<String> allowedNpcs;
  final List<String> allowedObstacles;
  final List<String> forbiddenReveals;

  /// Explicit exits out of the corridor before the turn budget is spent
  /// (e.g. choosing one of several access routes).
  final List<StoryChoice> choices;

  List<StoryChoice> availableChoices(Character character) => [
        for (final choice in choices)
          if (choice.isAvailableTo(character)) choice,
      ];

  /// Whether [turnsUsed] has exhausted this corridor's budget and it must
  /// force an exit via [fallbackExitNodeId].
  bool isBudgetExhausted(int turnsUsed) => turnsUsed >= turnBudget;

  factory BoundedCorridorNode.fromJson(String id, Map<String, dynamic> json) {
    return BoundedCorridorNode(
      id: id,
      goal: json['goal'] as String? ?? '',
      turnBudget: (json['turn_budget'] as num?)?.toInt() ?? 3,
      fallbackExitNodeId: json['fallback_exit'] as String,
      allowedLocations: _stringList(json['allowed_locations']),
      allowedNpcs: _stringList(json['allowed_npcs']),
      allowedObstacles: _stringList(json['allowed_obstacles']),
      forbiddenReveals: _stringList(json['forbidden_reveals']),
      choices: _choicesFromJson(json['choices']),
    );
  }
}

/// A hub of repeatable activities with no required order (§9.1: "dar
/// agencia"), plus a set of exits that advance the graph once the player is
/// ready to move on.
final class StateHubNode extends StoryNode {
  const StateHubNode({
    required super.id,
    this.activities = const [],
    this.exits = const [],
  });

  final List<HubActivity> activities;

  /// Choices that leave the hub and advance the graph.
  final List<StoryChoice> exits;

  List<HubActivity> availableActivities(Character character) => [
        for (final activity in activities)
          if (activity.isAvailableTo(character)) activity,
      ];

  List<StoryChoice> availableExits(Character character) => [
        for (final exit in exits)
          if (exit.isAvailableTo(character)) exit,
      ];

  factory StateHubNode.fromJson(String id, Map<String, dynamic> json) {
    return StateHubNode(
      id: id,
      activities: [
        for (final a in (json['activities'] as List? ?? const []))
          HubActivity.fromJson((a as Map).cast<String, dynamic>()),
      ],
      exits: _choicesFromJson(json['exits']),
    );
  }
}

/// The campaign's climax: a set of possible [Ending]s, each with hard/soft
/// requirements and a difficulty that scales with how many soft
/// requirements are met (§16).
final class ResolutionNode extends StoryNode {
  const ResolutionNode({
    required super.id,
    this.endings = const [],
    this.epilogueBeats = const [],
    this.finalTechniqueRules = const [],
  });

  final List<Ending> endings;

  /// Conditional epilogue beats (campaign-bible §16.8), grouped by
  /// `movement` — used by the pure epilogue node (`e_epilogo`), which offers
  /// no endings of its own.
  final List<EpilogueBeat> epilogueBeats;

  /// Priority rules for which technique to grant on entering the ritual
  /// (§7.5) — used by `c5_n03_ritual_final`, empty everywhere else.
  final List<FinalTechniqueRule> finalTechniqueRules;

  /// Endings whose hard requirement is currently satisfied. Soft
  /// requirements only affect [Ending.difficultyFor], never availability.
  List<Ending> availableEndings(Character character) => [
        for (final ending in endings)
          if (ending.isAvailableTo(character)) ending,
      ];

  factory ResolutionNode.fromJson(String id, Map<String, dynamic> json) {
    return ResolutionNode(
      id: id,
      endings: [
        for (final e in (json['endings'] as List? ?? const []))
          Ending.fromJson((e as Map).cast<String, dynamic>()),
      ],
      epilogueBeats: [
        for (final b in (json['epilogue_beats'] as List? ?? const []))
          EpilogueBeat.fromJson((b as Map).cast<String, dynamic>()),
      ],
      finalTechniqueRules: [
        for (final r in (json['final_technique_rules'] as List? ?? const []))
          FinalTechniqueRule.fromJson((r as Map).cast<String, dynamic>()),
      ],
    );
  }
}

List<StoryChoice> _choicesFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final c in value) StoryChoice.fromJson((c as Map).cast<String, dynamic>()),
  ];
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}
