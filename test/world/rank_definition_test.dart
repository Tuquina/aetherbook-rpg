import 'package:aetherbook/core/world/rank_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RankDefinition.fromJson', () {
    test('parses a milestone-gated rank', () {
      final rank = RankDefinition.fromJson({
        'id': 'meridiano_abierto',
        'level': 2,
        'exp_required': 5,
        'milestone_flag': 'reached_c1_n01_casa_de_tinta',
        'reward': 'Elegir una técnica inicial',
      });
      expect(rank.id, 'meridiano_abierto');
      expect(rank.level, 2);
      expect(rank.expRequired, 5);
      expect(rank.milestoneFlag, 'reached_c1_n01_casa_de_tinta');
      expect(rank.reward, 'Elegir una técnica inicial');
    });

    test('a rank with no milestone_flag is gated only by EXP', () {
      final rank = RankDefinition.fromJson({
        'id': 'aliento_velado',
        'level': 1,
        'exp_required': 0,
      });
      expect(rank.milestoneFlag, isNull);
      expect(rank.reward, '');
    });
  });
}
