/// How a world models advancement (GDD §4.3). Progression is *not* universal:
/// a xianxia world ascends through "reinos", a superhero one gains "niveles de
/// poder", and some stories track no levels at all. This keeps the terminology
/// and the very existence of leveling in data, so the engine and UI never
/// assume a "próximo reino" that a given story may not have (CLAUDE.md §8).
class Progression {
  const Progression({
    this.enabled = true,
    this.unitLabel = 'nivel',
    this.baseExpPerLevel = 300,
  });

  /// Whether this world levels up at all. When `false`, the UI hides the
  /// level/EXP chrome entirely.
  final bool enabled;

  /// Singular noun for one level, e.g. `'reino'`, `'nivel'`, `'rango'`.
  final String unitLabel;

  /// EXP needed to advance from level N to N+1 scales as `base * N`.
  final int baseExpPerLevel;

  /// `'Reino'`, `'Nivel'`… — the label capitalized for display.
  String get unitLabelCapitalized => unitLabel.isEmpty
      ? unitLabel
      : '${unitLabel[0].toUpperCase()}${unitLabel.substring(1)}';

  factory Progression.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const Progression();
    return Progression(
      enabled: json['enabled'] as bool? ?? true,
      unitLabel: json['unit_label'] as String? ?? 'nivel',
      baseExpPerLevel: (json['base_exp_per_level'] as num?)?.toInt() ?? 300,
    );
  }
}
