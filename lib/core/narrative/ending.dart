import '../state/character.dart';
import 'ending_fallback.dart';
import 'epilogue_beat.dart';
import 'gate.dart';

/// One possible ending inside a [ResolutionNode] (campaign-bible §16): a
/// hard requirement gates whether the ending is even offered; soft
/// requirements don't gate availability, but each one met makes the
/// resolving check easier — "con todos los requisitos blandos: DC 12; falta
/// una: DC 15; faltan dos: DC 18…" (§16.1). This models that curve directly
/// instead of hardcoding any campaign's specific numbers.
class Ending {
  const Ending({
    required this.id,
    required this.visibleChoice,
    this.hardRequirement = const AlwaysGate(),
    this.softRequirements = const [],
    this.difficultyBySoftRequirementsMet = const {},
    this.baseDifficulty = 15,
    this.successReveals = const [],
    this.costReveals = const [],
    this.failureCostOptions = const [],
    this.onFailureFallbacks = const [],
    this.bodyBeats = const [],
  });

  final String id;

  /// The option text shown to the player, e.g. "Abrir el Registro y devolver
  /// el peso a toda la ciudad."
  final String visibleChoice;

  /// Must be satisfied for this ending to be offered at all.
  final Gate hardRequirement;

  /// Each checked independently; met ones lower the resolving difficulty via
  /// [difficultyBySoftRequirementsMet]. They never block availability.
  final List<Gate> softRequirements;

  /// Count of soft requirements met -> difficulty for the resolving check.
  /// A count not listed here falls back to [baseDifficulty].
  final Map<int, int> difficultyBySoftRequirementsMet;
  final int baseDifficulty;

  /// Facts the narrator must include when narrating this ending's success
  /// (same spirit as `FixedAnchorNode.fixedReveals`).
  final List<String> successReveals;

  /// Facts the narrator must include when narrating this ending's cost.
  final List<String> costReveals;

  /// Possible costs on failure when there's more than one — the player picks
  /// (campaign-bible §16.2's three options on Portador del Margen's
  /// failure). Empty when failure has only one, fixed cost.
  final List<String> failureCostOptions;

  /// Redirects to a *different* `ending_id` on a failed resolution check —
  /// only `nuevo_pacto` uses this (§16.1). Every other ending's failure keeps
  /// the same `ending_id`, just with a worse narrated cost.
  final List<EndingFallback> onFailureFallbacks;

  /// Fully authored prose for this ending's body, assembled the same way as
  /// `ResolutionNode.epilogueBeats`: grouped by `movement` (e.g. "entrada",
  /// "variante_companero", "cierre" — a curated ending's own internal
  /// sections, campaign-bible §21), first satisfied beat per movement wins.
  /// Empty for hybrid/freeform endings, which narrate from [successReveals]/
  /// [costReveals] instead.
  final List<EpilogueBeat> bodyBeats;

  bool isAvailableTo(Character character) =>
      hardRequirement.isSatisfiedBy(character);

  /// The ending id this resolves to on a failed check: the first
  /// [onFailureFallbacks] entry whose gate [character] satisfies, or this
  /// ending's own [id] when there are no fallbacks (or none apply).
  String failureEndingIdFor(Character character) {
    for (final fallback in onFailureFallbacks) {
      if (fallback.isSatisfiedBy(character)) return fallback.endingId;
    }
    return id;
  }

  int softRequirementsMetBy(Character character) =>
      softRequirements.where((gate) => gate.isSatisfiedBy(character)).length;

  /// The difficulty for [character] to resolve this ending, given how many
  /// soft requirements they've met.
  int difficultyFor(Character character) {
    final met = softRequirementsMetBy(character);
    return difficultyBySoftRequirementsMet[met] ?? baseDifficulty;
  }

  factory Ending.fromJson(Map<String, dynamic> json) {
    return Ending(
      id: json['id'] as String,
      visibleChoice: json['visible_choice'] as String,
      hardRequirement: Gate.fromJson(
        (json['hard_requirement'] as Map?)?.cast<String, dynamic>(),
      ),
      softRequirements: _gatesFromJson(json['soft_requirements']),
      difficultyBySoftRequirementsMet:
          _difficultyMapFromJson(json['difficulty_by_soft_requirements_met']),
      baseDifficulty: (json['base_difficulty'] as num?)?.toInt() ?? 15,
      successReveals: _stringList(json['success_reveals']),
      costReveals: _stringList(json['cost_reveals']),
      failureCostOptions: _stringList(json['failure_cost_options']),
      onFailureFallbacks: _fallbacksFromJson(json['on_failure_fallbacks']),
      bodyBeats: _bodyBeatsFromJson(json['body_beats']),
    );
  }

  static List<EpilogueBeat> _bodyBeatsFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        EpilogueBeat.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  static List<Gate> _gatesFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        Gate.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  static Map<int, int> _difficultyMapFromJson(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, v) => MapEntry(int.parse(key as String), (v as num).toInt()),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static List<EndingFallback> _fallbacksFromJson(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        EndingFallback.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }
}
