import 'dart:math';

/// A source of dice rolls. It is injected into the engine so that action
/// resolution stays deterministic and testable — the engine never touches a
/// real RNG directly (CLAUDE.md §2.2, §9).
abstract class Dice {
  /// Returns an integer in the inclusive range `[1, sides]`.
  int roll(int sides);
}

/// Convenience helpers layered on top of [Dice].
extension DiceRolls on Dice {
  int rollD20() => roll(20);
}

/// Production dice backed by a pseudo-random generator.
class RandomDice implements Dice {
  RandomDice([Random? random]) : _random = random ?? Random();

  final Random _random;

  @override
  int roll(int sides) {
    if (sides < 1) {
      throw ArgumentError.value(sides, 'sides', 'must be >= 1');
    }
    return _random.nextInt(sides) + 1;
  }
}

/// Test dice that always returns the same face.
class FixedDice implements Dice {
  const FixedDice(this.value);

  final int value;

  @override
  int roll(int sides) => value;
}

/// Test dice that yields a predetermined sequence of faces, in order, looping
/// back to the start once exhausted.
class SequenceDice implements Dice {
  SequenceDice(this._values) : assert(_values.isNotEmpty);

  final List<int> _values;
  int _index = 0;

  @override
  int roll(int sides) {
    final value = _values[_index % _values.length];
    _index++;
    return value;
  }
}
