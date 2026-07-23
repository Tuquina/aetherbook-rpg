/// A named rank tied to a milestone, not just a linear EXP threshold
/// (campaign-bible §7.1): "la EXP puede acumularse antes de un hito de
/// rango, pero la promoción espera al hito." Promotion to this rank
/// requires **both** the character's cumulative EXP reaching [expRequired]
/// **and**, if [milestoneFlag] is set, that story flag being `true` (set
/// when the corresponding node completes — an ordinary `flag` delta, no new
/// mechanism needed). `milestoneFlag: null` means EXP alone is enough
/// (used for the starting rank).
class RankDefinition {
  const RankDefinition({
    required this.id,
    required this.level,
    required this.expRequired,
    this.milestoneFlag,
    this.reward = '',
  });

  final String id;
  final int level;
  final int expRequired;
  final String? milestoneFlag;

  /// Flavor description of what this rank unlocks (choose a technique,
  /// improve one…) — a content/UI concern, not mechanically enforced here.
  final String reward;

  factory RankDefinition.fromJson(Map<String, dynamic> json) {
    return RankDefinition(
      id: json['id'] as String,
      level: (json['level'] as num).toInt(),
      expRequired: (json['exp_required'] as num?)?.toInt() ?? 0,
      milestoneFlag: json['milestone_flag'] as String?,
      reward: json['reward'] as String? ?? '',
    );
  }
}
