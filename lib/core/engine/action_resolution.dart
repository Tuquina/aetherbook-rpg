/// The three outcome bands a resolved action can fall into (GDD §4.4).
enum ActionOutcome { failure, success, criticalSuccess }

/// Whether a check rolled a single d20, or 2d20 keeping the better/worse
/// face (campaign-bible §6.5). Multiple advantage sources never stack into
/// more dice; advantage and disadvantage together cancel to [normal] — both
/// rules are enforced by `combineRollModifiers`, not by this enum itself.
enum RollMode { normal, advantage, disadvantage }

/// Immutable result of resolving a player action. This is the object the
/// engine hands to the narrator: the mechanics are already decided, and the
/// AI's only job is to narrate them (CLAUDE.md §2.1, §5.1). The narrator
/// never recomputes any of these numbers.
class ActionResolution {
  const ActionResolution({
    required this.outcome,
    required this.attributeKey,
    required this.attribute,
    required this.modifiers,
    required this.roll,
    required this.difficulty,
    required this.total,
    required this.isNatural20,
    required this.isNatural1,
    this.rollMode = RollMode.normal,
    this.discardedRoll,
  });

  final ActionOutcome outcome;

  /// Which attribute this check was made against (e.g. `'cuerpo'`), decided
  /// deterministically in code (CLAUDE.md §2.2) — never by the AI. Lets the
  /// narrator and UI reflect which attribute mattered for this action.
  final String attributeKey;

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

  /// Whether [roll] came from a single d20 or 2d20 keeping the better/worse
  /// face (§6.5).
  final RollMode rollMode;

  /// The face that was rolled but *not* kept, when [rollMode] isn't
  /// [RollMode.normal] — kept around so the UI can show both dice.
  final int? discardedRoll;

  bool get isSuccess =>
      outcome == ActionOutcome.success ||
      outcome == ActionOutcome.criticalSuccess;

  @override
  String toString() =>
      'ActionResolution(outcome: $outcome, roll: $roll, total: $total, '
      'difficulty: $difficulty)';
}
