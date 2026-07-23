/// The three outcome bands a resolved action can fall into (GDD §4.4).
enum ActionOutcome { failure, success, criticalSuccess }

/// Immutable result of resolving a player action. This is the object the
/// engine hands to the narrator: the mechanics are already decided, and the
/// AI's only job is to narrate them (CLAUDE.md §2.1, §5.1). The narrator
/// never recomputes any of these numbers.
class ActionResolution {
  const ActionResolution({
    required this.outcome,
    required this.attribute,
    required this.modifiers,
    required this.roll,
    required this.difficulty,
    required this.total,
    required this.isNatural20,
    required this.isNatural1,
  });

  final ActionOutcome outcome;

  /// The attribute value used for the check.
  final int attribute;

  /// Situational modifiers applied on top of the attribute.
  final int modifiers;

  /// The raw d20 face (1..20).
  final int roll;

  /// Difficulty the total was compared against.
  final int difficulty;

  /// `attribute + modifiers + roll`.
  final int total;

  final bool isNatural20;
  final bool isNatural1;

  bool get isSuccess =>
      outcome == ActionOutcome.success ||
      outcome == ActionOutcome.criticalSuccess;

  @override
  String toString() =>
      'ActionResolution(outcome: $outcome, roll: $roll, total: $total, '
      'difficulty: $difficulty)';
}
