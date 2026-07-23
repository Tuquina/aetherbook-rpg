/// Which reward [VowReward] decided to grant.
enum VowRewardKind {
  /// Restore qi (or whatever resource key the caller names).
  restoreQi,

  /// +1 EXP — only offered when EXP wasn't already granted for the same
  /// action, per the campaign bible.
  grantExp,

  /// Advantage on the immediate roll. **Not yet appliable**: the
  /// advantage/disadvantage dice mechanic doesn't exist in the engine yet
  /// (a later phase). This variant exists so the policy matches the
  /// campaign-bible spec exactly; callers should only offer it once that
  /// mechanic lands.
  grantAdvantage,
}

class VowRewardOffer {
  const VowRewardOffer(this.kind, {this.amount = 0});

  final VowRewardKind kind;
  final int amount;
}

/// Decides which reward to grant when the player acts at a real cost in
/// favor of their vow, once per chapter (campaign-bible §5.4): restore qi,
/// grant advantage on the immediate roll, or grant `+1 exp` if EXP wasn't
/// already awarded for the same action. "A elección del motor según
/// contexto" — this class picks deterministically so the same situation
/// always resolves the same way:
///
///  1. If the named resource isn't known to be at its maximum, restore it —
///     always useful, and the safest default when there's no declared max.
///  2. Otherwise, if EXP wasn't already granted this action, grant EXP.
///  3. Otherwise, offer advantage on the immediate roll.
///
/// This class only *decides*; it doesn't roll dice or touch state. Applying
/// `restoreQi`/`grantExp` reuses the existing `resource`/`exp` state deltas
/// today. Applying `grantAdvantage` needs the advantage/disadvantage
/// mechanic (not built yet).
class VowReward {
  const VowReward({this.qiRestoreAmount = 2, this.expGrantAmount = 1});

  final int qiRestoreAmount;
  final int expGrantAmount;

  VowRewardOffer decide({
    required int currentQi,
    int? maxQi,
    required bool expAlreadyGrantedThisAction,
  }) {
    if (maxQi == null || currentQi < maxQi) {
      return VowRewardOffer(VowRewardKind.restoreQi, amount: qiRestoreAmount);
    }
    if (!expAlreadyGrantedThisAction) {
      return VowRewardOffer(VowRewardKind.grantExp, amount: expGrantAmount);
    }
    return const VowRewardOffer(VowRewardKind.grantAdvantage);
  }
}
