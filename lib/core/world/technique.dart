/// An upgrade a [Technique] can gain later (campaign-bible §7.3: every
/// initial technique has one), spending more qi for a stronger effect.
class TechniqueUpgrade {
  const TechniqueUpgrade({
    required this.id,
    this.costQi = 0,
    this.effect = '',
  });

  final String id;
  final int costQi;
  final String effect;

  factory TechniqueUpgrade.fromJson(Map<String, dynamic> json) {
    return TechniqueUpgrade(
      id: json['id'] as String,
      costQi: (json['cost_qi'] as num?)?.toInt() ?? 0,
      effect: json['effect'] as String? ?? '',
    );
  }
}

/// A declared technique (campaign-bible §7.3-7.5): an initial technique
/// (costs qi), the forbidden `devorar_el_margen` (costs ledger debt instead,
/// offers a choice of effects), or a final technique granted at the ritual.
/// Purely descriptive/content data — how a technique's `mechanicalBonus`
/// actually cashes out (granting advantage, extra guard damage...) is
/// `GameController` wiring, deferred to Fase 8, same as advantage/guard
/// themselves were after Fase 5.
class Technique {
  const Technique({
    required this.id,
    required this.displayName,
    this.costQi = 0,
    this.costLedgerDebt = 0,
    this.primaryAttribute,
    this.effect = '',
    this.mechanicalBonus = '',
    this.effectOptions = const [],
    this.restriction = '',
    this.upgrade,
  });

  final String id;
  final String displayName;
  final int costQi;
  final int costLedgerDebt;

  /// `null` for `devorar_el_margen`, which isn't tied to one attribute.
  final String? primaryAttribute;

  final String effect;
  final String mechanicalBonus;

  /// Alternative effects the player picks from when using this technique
  /// (only `devorar_el_margen` uses this — §7.4's three options).
  final List<String> effectOptions;

  /// Flavor/usage restriction text, e.g. "máximo una vez por nodo".
  final String restriction;

  final TechniqueUpgrade? upgrade;

  factory Technique.fromJson(Map<String, dynamic> json) {
    return Technique(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? json['id'] as String,
      costQi: (json['cost_qi'] as num?)?.toInt() ?? 0,
      costLedgerDebt: (json['cost_ledger_debt'] as num?)?.toInt() ?? 0,
      primaryAttribute: json['primary_attribute'] as String?,
      effect: json['effect'] as String? ?? '',
      mechanicalBonus: json['mechanical_bonus'] as String? ?? '',
      effectOptions: json['effect_options'] is List
          ? (json['effect_options'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const [],
      restriction: json['restriction'] as String? ?? '',
      upgrade: json['upgrade'] is Map
          ? TechniqueUpgrade.fromJson(
              (json['upgrade'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}
