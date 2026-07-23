import '../state/character.dart';
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

  bool isAvailableTo(Character character) =>
      hardRequirement.isSatisfiedBy(character);

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
    );
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
}
