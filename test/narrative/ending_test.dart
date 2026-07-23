import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/ending_fallback.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:flutter_test/flutter_test.dart';

const _character = Character(
  name: 'Discípulo',
  level: 1,
  exp: 0,
  attributes: {},
  resources: {},
);

void main() {
  group('Ending — failure fallbacks (campaign-bible §16.1)', () {
    test('failureEndingIdFor is the ending\'s own id when there are no fallbacks', () {
      const ending = Ending(id: 'cielo_roto', visibleChoice: 'x');
      expect(ending.failureEndingIdFor(_character), 'cielo_roto');
    });

    test('falls back to the first matching fallback\'s ending id', () {
      const ending = Ending(
        id: 'nuevo_pacto',
        visibleChoice: 'x',
        onFailureFallbacks: [
          EndingFallback(
            gate: MinMeterGate('ledger_debt', 4),
            endingId: 'nuevo_pacto_fracturado',
          ),
          EndingFallback(gate: AlwaysGate(), endingId: 'portador_del_margen'),
        ],
      );
      expect(ending.failureEndingIdFor(_character), 'portador_del_margen');
      expect(
        ending.failureEndingIdFor(_character.copyWith(meters: {'ledger_debt': 4})),
        'nuevo_pacto_fracturado',
      );
    });
  });

  group('Ending.fromJson — new descriptive fields', () {
    test('parses successReveals, costReveals and failureCostOptions', () {
      final ending = Ending.fromJson({
        'id': 'portador_del_margen',
        'visible_choice': 'x',
        'success_reveals': ['El protagonista absorbe los nombres amputados.'],
        'cost_reveals': ['Pierde la posibilidad de un nombre celeste estable.'],
        'failure_cost_options': [
          'olvida su juramento',
          'pierde el recuerdo del objeto personal',
          'un aliado comparte la carga',
        ],
      });
      expect(ending.successReveals, hasLength(1));
      expect(ending.costReveals, hasLength(1));
      expect(ending.failureCostOptions, hasLength(3));
    });

    test('parses onFailureFallbacks', () {
      final ending = Ending.fromJson({
        'id': 'nuevo_pacto',
        'visible_choice': 'x',
        'on_failure_fallbacks': [
          {
            'gate': {'type': 'meter', 'key': 'ledger_debt', 'min': 0},
            'ending_id': 'portador_del_margen',
          },
        ],
      });
      expect(ending.onFailureFallbacks.single.endingId, 'portador_del_margen');
    });

    test('defaults all new fields to empty', () {
      final ending = Ending.fromJson({'id': 'x', 'visible_choice': 'y'});
      expect(ending.successReveals, isEmpty);
      expect(ending.costReveals, isEmpty);
      expect(ending.failureCostOptions, isEmpty);
      expect(ending.onFailureFallbacks, isEmpty);
    });
  });
}
