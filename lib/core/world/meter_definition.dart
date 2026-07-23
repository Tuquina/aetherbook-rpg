import '../state/character.dart';

/// Declares a named narrative-economy counter (a "meter" on [Character]) —
/// e.g. a campaign bible's `karma` (bounded -3..3), `celestial_pressure`
/// (escalates the story), or `ledger_debt` (unbounded, gates endings).
/// Optional bounds let [ApplyStateDeltas] clamp deterministically instead of
/// every campaign reinventing its own clamping.
///
/// A meter can also be **derived**: its value isn't stored directly but
/// computed from story flags (e.g. `evidence_count` = how many of four
/// `evidence_*` flags are true). A derived meter must never be edited by a
/// direct delta — only by the flags changing.
class MeterDefinition {
  const MeterDefinition({
    this.min,
    this.max,
    this.initial = 0,
    this.derivedFromFlags,
  });

  /// Inclusive lower bound, or `null` for unbounded below.
  final int? min;

  /// Inclusive upper bound, or `null` for unbounded above.
  final int? max;

  /// Starting value for a stored (non-derived) meter.
  final int initial;

  /// When set, this meter's value is the count of these flags that are
  /// `true` on the character — it is never stored or edited directly.
  final List<String>? derivedFromFlags;

  bool get isDerived => derivedFromFlags != null;

  int clamp(int value) {
    var result = value;
    final lo = min;
    final hi = max;
    if (lo != null && result < lo) result = lo;
    if (hi != null && result > hi) result = hi;
    return result;
  }

  /// The meter's effective current value for [character]: the derived count
  /// of true flags, or the clamped stored value under [key].
  int resolve(Character character, String key) {
    final flagKeys = derivedFromFlags;
    if (flagKeys != null) {
      return flagKeys.where(character.flag).length;
    }
    return clamp(character.meter(key));
  }

  factory MeterDefinition.fromJson(Map<String, dynamic> json) {
    return MeterDefinition(
      min: (json['min'] as num?)?.toInt(),
      max: (json['max'] as num?)?.toInt(),
      initial: (json['initial'] as num?)?.toInt() ?? 0,
      derivedFromFlags: json['derived_from_flags'] is List
          ? (json['derived_from_flags'] as List)
              .whereType<String>()
              .toList(growable: false)
          : null,
    );
  }
}
