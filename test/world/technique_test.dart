import 'package:aetherbook/core/world/technique.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Technique.fromJson', () {
    test('parses an initial technique with its upgrade', () {
      final technique = Technique.fromJson({
        'id': 'paso_entre_trazos',
        'cost_qi': 1,
        'primary_attribute': 'agudeza',
        'effect': 'Atravesar durante un instante una barrera.',
        'mechanical_bonus': 'ventaja contra sellos',
        'upgrade': {
          'id': 'paso_fuera_del_margen',
          'cost_qi': 2,
          'effect': 'Incluye a un aliado o evita una consecuencia.',
        },
      });

      expect(technique.id, 'paso_entre_trazos');
      expect(technique.costQi, 1);
      expect(technique.costLedgerDebt, 0);
      expect(technique.primaryAttribute, 'agudeza');
      expect(technique.upgrade!.id, 'paso_fuera_del_margen');
      expect(technique.upgrade!.costQi, 2);
    });

    test('parses the forbidden technique with effect options and no primary attribute', () {
      final technique = Technique.fromJson({
        'id': 'devorar_el_margen',
        'cost_qi': 0,
        'cost_ledger_debt': 1,
        'effect_options': [
          'repetir una tirada y conservar el mejor resultado',
          'usar una técnica sin pagar qi',
          'convertir una falla en éxito con una consecuencia',
        ],
        'restriction': 'máximo una vez por nodo',
      });

      expect(technique.primaryAttribute, isNull);
      expect(technique.costLedgerDebt, 1);
      expect(technique.effectOptions, hasLength(3));
      expect(technique.restriction, 'máximo una vez por nodo');
      expect(technique.upgrade, isNull);
    });

    test('defaults display name to id and costs to zero', () {
      final technique = Technique.fromJson({'id': 'yo_me_nombro'});
      expect(technique.displayName, 'yo_me_nombro');
      expect(technique.costQi, 0);
      expect(technique.costLedgerDebt, 0);
      expect(technique.effectOptions, isEmpty);
    });
  });
}
