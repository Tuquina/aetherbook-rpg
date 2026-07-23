import 'package:aetherbook/core/engine/exp_progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpProgression', () {
    const progression = ExpProgression(baseExpPerLevel: 300);

    test('expToNext scales linearly with level', () {
      expect(progression.expToNext(1), 300);
      expect(progression.expToNext(2), 600);
      expect(progression.expToNext(3), 900);
    });

    test('no level-up when gained exp is below threshold', () {
      final result = progression.applyExp(level: 1, exp: 0, gainedExp: 120);
      expect(result.level, 1);
      expect(result.exp, 120);
      expect(result.levelsGained, 0);
    });

    test('single level-up carries remainder forward', () {
      final result = progression.applyExp(level: 1, exp: 250, gainedExp: 120);
      // 250 + 120 = 370; needs 300 -> level 2, 70 left over.
      expect(result.level, 2);
      expect(result.exp, 70);
      expect(result.levelsGained, 1);
    });

    test('multiple level-ups roll over across increasing thresholds', () {
      // From level 1 with a big lump: 1000 exp.
      // L1 needs 300 -> 700 left, L2. L2 needs 600 -> 100 left, L3.
      final result = progression.applyExp(level: 1, exp: 0, gainedExp: 1000);
      expect(result.level, 3);
      expect(result.exp, 100);
      expect(result.levelsGained, 2);
    });

    test('exactly hitting the threshold levels up with 0 remainder', () {
      final result = progression.applyExp(level: 1, exp: 0, gainedExp: 300);
      expect(result.level, 2);
      expect(result.exp, 0);
      expect(result.levelsGained, 1);
    });

    test('rejects negative gained exp', () {
      expect(
        () => progression.applyExp(level: 1, exp: 0, gainedExp: -1),
        throwsArgumentError,
      );
    });
  });
}
