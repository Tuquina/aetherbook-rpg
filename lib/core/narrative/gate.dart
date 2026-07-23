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
