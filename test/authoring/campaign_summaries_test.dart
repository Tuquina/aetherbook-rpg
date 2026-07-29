import 'package:aetherbook/core/authoring/campaign_summaries.dart';
import 'package:aetherbook/core/engine/state_delta.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CampaignSummaries.gate', () {
    test('describes a FlagGate', () {
      expect(CampaignSummaries.gate(const FlagGate('marca_sello')), contains('marca_sello'));
      expect(CampaignSummaries.gate(const FlagGate('marca_sello', false)), contains('No tiene'));
    });

    test('describes a MinAttributeGate', () {
      expect(CampaignSummaries.gate(const MinAttributeGate('cultivo', 2)), 'cultivo es 2 o más');
    });

    test('describes AlwaysGate as "Siempre"', () {
      expect(CampaignSummaries.gate(const AlwaysGate()), 'Siempre');
    });
  });

  group('CampaignSummaries.stateDelta', () {
    test('shows a + sign for a positive exp delta', () {
      const delta = StateDelta(type: StateDeltaType.exp, key: 'exp', value: 30);
      expect(CampaignSummaries.stateDelta(delta), contains('+30'));
    });

    test('shows no + sign for a negative relationship delta', () {
      const delta = StateDelta(type: StateDeltaType.relationship, key: 'anciano', value: -2);
      final summary = CampaignSummaries.stateDelta(delta);
      expect(summary, contains('-2'));
      expect(summary, isNot(contains('+-2')));
    });

    test('describes a flag delta', () {
      const delta = StateDelta(type: StateDeltaType.flag, key: 'el_porton_te_vio', value: true);
      expect(CampaignSummaries.stateDelta(delta), contains('el_porton_te_vio'));
    });
  });

  group('DifficultyPreset', () {
    test('forValue matches the 5 standard difficulties', () {
      expect(DifficultyPreset.forValue(9), DifficultyPreset.facil);
      expect(DifficultyPreset.forValue(12), DifficultyPreset.normal);
      expect(DifficultyPreset.forValue(15), DifficultyPreset.dificil);
      expect(DifficultyPreset.forValue(18), DifficultyPreset.muyDificil);
      expect(DifficultyPreset.forValue(21), DifficultyPreset.casiImposible);
    });

    test('forValue is null for a non-standard difficulty', () {
      expect(DifficultyPreset.forValue(13), isNull);
    });
  });
}
