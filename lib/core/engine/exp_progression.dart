/// Deterministic experience / level progression. Pure functions: the engine
/// owns progression, never the AI (CLAUDE.md §2.2). Reused across every world;
/// only the theme (reinos, niveles de poder, street cred…) changes (GDD §4.3).
class ExpProgression {
  const ExpProgression({this.baseExpPerLevel = 300});

  /// EXP required to advance from a level to the next one scales linearly:
  /// `baseExpPerLevel * level`.
  final int baseExpPerLevel;

  /// EXP required to advance **from** [level] to `level + 1`.
  int expToNext(int level) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be >= 1');
    }
    return baseExpPerLevel * level;
  }

  /// Applies [gainedExp] on top of a current [level]/[exp], rolling over into
  /// as many level-ups as the totals allow. Returns the resulting progress.
  LevelProgress applyExp({
    required int level,
    required int exp,
    required int gainedExp,
  }) {
    if (level < 1) {
      throw ArgumentError.value(level, 'level', 'must be >= 1');
    }
    if (exp < 0) {
      throw ArgumentError.value(exp, 'exp', 'must be >= 0');
    }
    if (gainedExp < 0) {
      throw ArgumentError.value(gainedExp, 'gainedExp', 'must be >= 0');
    }

    var newLevel = level;
    var newExp = exp + gainedExp;
    var levelsGained = 0;
    while (newExp >= expToNext(newLevel)) {
      newExp -= expToNext(newLevel);
      newLevel += 1;
      levelsGained += 1;
    }
    return LevelProgress(
      level: newLevel,
      exp: newExp,
      levelsGained: levelsGained,
    );
  }
}

/// Result of applying EXP: the new level/exp and how many level-ups happened
/// (useful for the UI to celebrate a level-up).
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.exp,
    required this.levelsGained,
  });

  final int level;
  final int exp;
  final int levelsGained;
}
