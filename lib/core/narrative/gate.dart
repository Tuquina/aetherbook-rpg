import '../state/character.dart';

/// A requirement for a [StoryChoice] to be available (GDD §4.1: "Condición/
/// gate: requisitos para que una opción aparezca"). Pure and side-effect
/// free — evaluated against a [Character] snapshot only.
abstract class Gate {
  const Gate();

  bool isSatisfiedBy(Character character);

  factory Gate.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AlwaysGate();
    switch (json['type'] as String) {
      case 'flag':
        return FlagGate(
          json['key'] as String,
          json['equals'] as bool? ?? true,
        );
      case 'level':
        return MinLevelGate((json['min'] as num).toInt());
      case 'attribute':
        return MinAttributeGate(
          json['key'] as String,
          (json['min'] as num).toInt(),
        );
      case 'resource':
        return MinResourceGate(
          json['key'] as String,
          (json['min'] as num).toInt(),
        );
      case 'meter':
        if (json.containsKey('max')) {
          return MaxMeterGate(
            json['key'] as String,
            (json['max'] as num).toInt(),
          );
        }
        return MinMeterGate(
          json['key'] as String,
          (json['min'] as num).toInt(),
        );
      case 'relationship':
        if (json.containsKey('max')) {
          return MaxRelationshipGate(
            json['key'] as String,
            (json['max'] as num).toInt(),
          );
        }
        return MinRelationshipGate(
          json['key'] as String,
          (json['min'] as num).toInt(),
        );
      case 'var':
        return VarGate(json['key'] as String, json['equals'] as String);
      case 'list':
        return ListContainsGate(
          json['key'] as String,
          json['value'] as String,
          json['equals'] as bool? ?? true,
        );
      case 'all':
        return AllOfGate([
          for (final g in json['gates'] as List)
            Gate.fromJson((g as Map).cast<String, dynamic>()),
        ]);
      case 'any':
        return AnyOfGate([
          for (final g in json['gates'] as List)
            Gate.fromJson((g as Map).cast<String, dynamic>()),
        ]);
      default:
        throw ArgumentError('unknown gate type: ${json['type']}');
    }
  }
}

/// No requirement — the choice is always available.
class AlwaysGate extends Gate {
  const AlwaysGate();

  @override
  bool isSatisfiedBy(Character character) => true;
}

/// Requires a story flag to equal [expected] (default `true`).
class FlagGate extends Gate {
  const FlagGate(this.key, [this.expected = true]);

  final String key;
  final bool expected;

  @override
  bool isSatisfiedBy(Character character) => character.flag(key) == expected;
}

/// Requires the character's level to be at least [minLevel].
class MinLevelGate extends Gate {
  const MinLevelGate(this.minLevel);

  final int minLevel;

  @override
  bool isSatisfiedBy(Character character) => character.level >= minLevel;
}

/// Requires an attribute to be at least [minValue].
class MinAttributeGate extends Gate {
  const MinAttributeGate(this.key, this.minValue);

  final String key;
  final int minValue;

  @override
  bool isSatisfiedBy(Character character) =>
      character.attribute(key) >= minValue;
}

/// Requires a resource to be at least [minValue].
class MinResourceGate extends Gate {
  const MinResourceGate(this.key, this.minValue);

  final String key;
  final int minValue;

  @override
  bool isSatisfiedBy(Character character) =>
      character.resource(key) >= minValue;
}

/// Requires a named meter (karma, celestial_pressure, evidence_count…) to be
/// at least [minValue]. Reads `character.meter(key)` directly — for a
/// *derived* meter (e.g. `evidence_count`) this relies on
/// `ApplyStateDeltas` keeping the derived value synced onto the character
/// each turn (see its doc comment), so this stays a pure, `World`-free check.
class MinMeterGate extends Gate {
  const MinMeterGate(this.key, this.minValue);

  final String key;
  final int minValue;

  @override
  bool isSatisfiedBy(Character character) => character.meter(key) >= minValue;
}

/// Requires a named meter to be at most [maxValue] — the upper-bound twin of
/// [MinMeterGate], needed by curated content phrased as a ceiling (e.g.
/// "Infección < 3", modeled as `max: 2`).
class MaxMeterGate extends Gate {
  const MaxMeterGate(this.key, this.maxValue);

  final String key;
  final int maxValue;

  @override
  bool isSatisfiedBy(Character character) => character.meter(key) <= maxValue;
}

/// Requires a per-NPC relationship (karma, celestial_pressure sit on
/// [MinMeterGate]; this is specifically `character.relationships`) to be at
/// least [minValue] — e.g. gating a final technique on a deep bond with an
/// ally (campaign-bible §7.5's "relación total con aliados").
class MinRelationshipGate extends Gate {
  const MinRelationshipGate(this.key, this.minValue);

  final String key;
  final int minValue;

  @override
  bool isSatisfiedBy(Character character) =>
      character.relationship(key) >= minValue;
}

/// Requires a per-NPC relationship to be at most [maxValue] — the
/// upper-bound twin of [MinRelationshipGate], used to make a "high
/// relationship" branch and its "otherwise" counterpart mutually exclusive
/// (e.g. an option that only stings when the bond is already close).
class MaxRelationshipGate extends Gate {
  const MaxRelationshipGate(this.key, this.maxValue);

  final String key;
  final int maxValue;

  @override
  bool isSatisfiedBy(Character character) =>
      character.relationship(key) <= maxValue;
}

/// Requires a named free-form var (`character.vars[key]`, see
/// `Character.vars`) to equal [equals] — e.g. gating content on which
/// chargen origin/vow was picked (`CreateCharacter` mirrors both into
/// `vars['origin_id']`/`vars['vow_id']`) or on a curated policy choice like
/// `vars['passenger_policy']`. One generic mechanism instead of a dedicated
/// gate per enum-like concept.
class VarGate extends Gate {
  const VarGate(this.key, this.equals);

  final String key;
  final String equals;

  @override
  bool isSatisfiedBy(Character character) => character.varValue(key) == equals;
}

/// Requires a named string list (`character.lists[key]`, see `Character.
/// lists`) to contain (or, with [expected] `false`, not contain) [value] —
/// e.g. gating a choice on carrying a specific inventory item:
/// `{"type": "list", "key": "inventory", "value": "fusible_industrial"}`.
class ListContainsGate extends Gate {
  const ListContainsGate(this.key, this.value, [this.expected = true]);

  final String key;
  final String value;
  final bool expected;

  @override
  bool isSatisfiedBy(Character character) =>
      character.list(key).contains(value) == expected;
}

/// Composite: satisfied only if every sub-[gates] is satisfied.
class AllOfGate extends Gate {
  const AllOfGate(this.gates);

  final List<Gate> gates;

  @override
  bool isSatisfiedBy(Character character) =>
      gates.every((g) => g.isSatisfiedBy(character));
}

/// Composite: satisfied if any sub-[gates] is satisfied.
class AnyOfGate extends Gate {
  const AnyOfGate(this.gates);

  final List<Gate> gates;

  @override
  bool isSatisfiedBy(Character character) =>
      gates.any((g) => g.isSatisfiedBy(character));
}
