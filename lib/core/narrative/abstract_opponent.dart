import '../engine/action_resolution.dart';

/// An opponent modeled by "guard" instead of hit points (campaign-bible
/// §6.13): a check doesn't deal arbitrary damage, it chips away at a small,
/// countable defense. A regular success reduces guard by `1`; a critical
/// success reduces it by `2`. At `0` the opponent is defeated — the player
/// (not this class) picks a fictionally compatible resolution: surrender,
/// flight, restraint, or death only when the tone allows it.
///
/// "Fallar permite al oponente actuar. El motor aplica una consecuencia
/// predefinida" — [typicalDamage] is that predefined consequence's size; a
/// content/UI concern decides what it actually does to the character.
class AbstractOpponent {
  const AbstractOpponent({
    required this.id,
    required this.displayName,
    required this.maxGuard,
    this.typicalDamage = 0,
    this.nonviolentAlternative = '',
  });

  final String id;
  final String displayName;
  final int maxGuard;
  final int typicalDamage;

  /// A non-violent way to resolve this encounter instead (flavor text, e.g.
  /// "Engaño, autoridad, distracción").
  final String nonviolentAlternative;

  /// Guard remaining after one attempt against this opponent with [outcome],
  /// clamped to `[0, maxGuard]`. A failure leaves guard unchanged — it's the
  /// opponent's turn to act instead (handled elsewhere).
  int guardAfter(int currentGuard, ActionOutcome outcome) {
    final damage = switch (outcome) {
      ActionOutcome.criticalSuccess => 2,
      ActionOutcome.success => 1,
      ActionOutcome.failure => 0,
    };
    final next = currentGuard - damage;
    if (next < 0) return 0;
    if (next > maxGuard) return maxGuard;
    return next;
  }

  bool isDefeated(int currentGuard) => currentGuard <= 0;

  factory AbstractOpponent.fromJson(Map<String, dynamic> json) {
    return AbstractOpponent(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      maxGuard: (json['guard'] as num).toInt(),
      typicalDamage: (json['typical_damage'] as num?)?.toInt() ?? 0,
      nonviolentAlternative: json['nonviolent_alternative'] as String? ?? '',
    );
  }
}
