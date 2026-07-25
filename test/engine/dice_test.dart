// Statistical sanity check for RandomDice (reported: freeform play "felt"
// like it kept rolling 1s/low faces — CLAUDE.md Fase 2 follow-up). This
// can't prove randomness, but over a large sample it catches the two real
// bugs that would produce that symptom: a broken/biased mapping in `roll()`,
// or an RNG that's degenerate (always the same value, or skewed hard toward
// one end).
import 'package:aetherbook/core/engine/dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RandomDice', () {
    test('roll(1) always returns 1 (no space for anything else)', () {
      final dice = RandomDice();
      for (var i = 0; i < 20; i++) {
        expect(dice.roll(1), 1);
      }
    });

    test('throws for a non-positive number of sides', () {
      final dice = RandomDice();
      expect(() => dice.roll(0), throwsArgumentError);
      expect(() => dice.roll(-3), throwsArgumentError);
    });

    test('rollD20 stays within [1, 20] over a large sample', () {
      final dice = RandomDice();
      for (var i = 0; i < 5000; i++) {
        final roll = dice.rollD20();
        expect(roll, inInclusiveRange(1, 20));
      }
    });

    test('rollD20 hits every face at least once over a large sample '
        '(rules out a degenerate/constant generator)', () {
      final dice = RandomDice();
      final seen = <int>{};
      for (var i = 0; i < 20000; i++) {
        seen.add(dice.rollD20());
      }
      expect(seen, hasLength(20),
          reason: 'expected all 20 faces to appear at least once in 20000 '
              'rolls; saw only $seen');
    });

    test('rollD20 average lands close to the fair-die expectation of 10.5, '
        'not skewed low', () {
      final dice = RandomDice();
      const sampleSize = 20000;
      var sum = 0;
      for (var i = 0; i < sampleSize; i++) {
        sum += dice.rollD20();
      }
      final average = sum / sampleSize;
      // A fair d20's mean is 10.5; the standard error over 20k rolls is
      // tiny (~0.026), so a generous +-0.5 band is already well beyond
      // sampling noise and only fails on a genuinely biased generator.
      expect(average, closeTo(10.5, 0.5),
          reason: 'average roll $average suggests the generator is biased '
              'toward low (or high) faces, not uniformly random');
    });

    test('the bottom quarter of faces (1-5) shows up close to 25% of the '
        'time, not noticeably more often', () {
      final dice = RandomDice();
      const sampleSize = 20000;
      var lowCount = 0;
      for (var i = 0; i < sampleSize; i++) {
        if (dice.rollD20() <= 5) lowCount++;
      }
      final lowFraction = lowCount / sampleSize;
      // Expected 25%; a generous +-5 point band comfortably covers sampling
      // noise (std dev ~0.3%) while still catching a real skew-low bug.
      expect(lowFraction, closeTo(0.25, 0.05),
          reason: 'rolls of 1-5 came up ${(lowFraction * 100).toStringAsFixed(1)}%'
              ' of the time, well above the fair-die 25%');
    });
  });
}
