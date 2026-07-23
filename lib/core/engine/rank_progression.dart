import '../world/rank_definition.dart';

/// Result of evaluating rank progression: the resolved rank, level, running
/// EXP total, and how many ranks were gained in this evaluation.
class RankResult {
  const RankResult({
    required this.rankId,
    required this.level,
    required this.exp,
    required this.levelsGained,
  });

  final String rankId;
  final int level;
  final int exp;
  final int levelsGained;
}

/// Milestone-gated rank progression (campaign-bible §7.1). Unlike the
/// simpler linear `ExpProgression` (a cost-per-level threshold, exp rolls
/// over on level-up), rank EXP is a **cumulative running total** — the
/// thresholds in a campaign bible are absolute ("5 EXP", "12 EXP", "21
/// EXP"), never subtracted.
///
/// Promotion to the next rank requires both the cumulative EXP threshold
/// *and* that rank's milestone story flag (if any). Reaching the EXP early
/// just "banks" it — the promotion happens whenever the milestone is
/// eventually reached, even without any further EXP gain in that turn.
class RankProgression {
  const RankProgression(this.ranks);

  /// Every rank this campaign declares.
  final List<RankDefinition> ranks;

  /// Adds [gainedExp] to the running total and promotes through as many
  /// ranks, in order, as the (now cumulative) EXP and each rank's milestone
  /// flag allow — stopping at the first rank whose requirements aren't met.
  RankResult applyExp({
    required int currentLevel,
    required int currentExp,
    required int gainedExp,
    required bool Function(String flagKey) hasFlag,
  }) {
    final totalExp = currentExp + gainedExp;
    var level = currentLevel;
    var levelsGained = 0;

    while (true) {
      final next = rankAt(level + 1);
      if (next == null) break;
      final expMet = totalExp >= next.expRequired;
      final milestoneMet =
          next.milestoneFlag == null || hasFlag(next.milestoneFlag!);
      if (!expMet || !milestoneMet) break;
      level = next.level;
      levelsGained++;
    }

    return RankResult(
      rankId: rankAt(level)?.id ?? '',
      level: level,
      exp: totalExp,
      levelsGained: levelsGained,
    );
  }

  RankDefinition? rankAt(int level) {
    for (final rank in ranks) {
      if (rank.level == level) return rank;
    }
    return null;
  }
}
