import 'package:aetherbook/core/engine/rank_progression.dart';
import 'package:aetherbook/core/world/rank_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const _ranks = [
  RankDefinition(id: 'aliento_velado', level: 1, expRequired: 0),
  RankDefinition(
    id: 'meridiano_abierto',
    level: 2,
    expRequired: 5,
    milestoneFlag: 'reached_casa_de_tinta',
  ),
  RankDefinition(
    id: 'eco_encarnado',
    level: 3,
    expRequired: 12,
    milestoneFlag: 'reached_pozo_de_los_ecos',
  ),
  RankDefinition(
    id: 'nombre_propio',
    level: 4,
    expRequired: 21,
    milestoneFlag: 'started_ritual_final',
  ),
];

void main() {
  const progression = RankProgression(_ranks);

  group('RankProgression.applyExp', () {
    test('accumulates EXP without promoting when the milestone is not reached', () {
      final result = progression.applyExp(
        currentLevel: 1,
        currentExp: 0,
        gainedExp: 8, // clears the level-2 EXP requirement (5)...
        hasFlag: (_) => false, // ...but the milestone hasn't happened.
      );
      expect(result.exp, 8);
      expect(result.level, 1);
      expect(result.rankId, 'aliento_velado');
      expect(result.levelsGained, 0);
    });

    test('promotes as soon as both EXP and milestone are satisfied', () {
      final result = progression.applyExp(
        currentLevel: 1,
        currentExp: 0,
        gainedExp: 8,
        hasFlag: (flag) => flag == 'reached_casa_de_tinta',
      );
      expect(result.level, 2);
      expect(result.rankId, 'meridiano_abierto');
      expect(result.levelsGained, 1);
    });

    test('banked EXP promotes later, even with zero additional gain, once the flag lands', () {
      // Turn 1: gains enough EXP, but the milestone hasn't happened yet.
      final afterExp = progression.applyExp(
        currentLevel: 1,
        currentExp: 0,
        gainedExp: 8,
        hasFlag: (_) => false,
      );
      expect(afterExp.level, 1);

      // Turn 2: no new EXP at all — only the milestone flag just became true.
      final afterMilestone = progression.applyExp(
        currentLevel: afterExp.level,
        currentExp: afterExp.exp,
        gainedExp: 0,
        hasFlag: (flag) => flag == 'reached_casa_de_tinta',
      );
      expect(afterMilestone.level, 2);
      expect(afterMilestone.rankId, 'meridiano_abierto');
      expect(afterMilestone.exp, 8);
    });

    test('cannot skip a rank even with overwhelming EXP if an earlier milestone is missing', () {
      final result = progression.applyExp(
        currentLevel: 1,
        currentExp: 0,
        gainedExp: 999,
        // level 3's milestone is reached, but level 2's never was.
        hasFlag: (flag) => flag == 'reached_pozo_de_los_ecos',
      );
      expect(result.level, 1);
      expect(result.levelsGained, 0);
    });

    test('promotes through multiple ranks in one call when every gate is met', () {
      final result = progression.applyExp(
        currentLevel: 1,
        currentExp: 0,
        gainedExp: 999,
        hasFlag: (flag) =>
            flag == 'reached_casa_de_tinta' || flag == 'reached_pozo_de_los_ecos',
      );
      expect(result.level, 3);
      expect(result.rankId, 'eco_encarnado');
      expect(result.levelsGained, 2);
    });

    test('stays put when there is no next rank defined', () {
      final result = progression.applyExp(
        currentLevel: 4,
        currentExp: 21,
        gainedExp: 5,
        hasFlag: (_) => true,
      );
      expect(result.level, 4);
      expect(result.exp, 26);
      expect(result.levelsGained, 0);
    });
  });

  group('RankProgression.rankAt', () {
    test('finds a rank by level', () {
      expect(progression.rankAt(2)?.id, 'meridiano_abierto');
    });

    test('returns null for an undeclared level', () {
      expect(progression.rankAt(99), isNull);
    });
  });
}
