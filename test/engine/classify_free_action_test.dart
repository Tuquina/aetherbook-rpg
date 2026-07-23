import 'package:aetherbook/core/engine/classify_free_action.dart';
import 'package:aetherbook/core/engine/free_action_classification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const classify = ClassifyFreeAction();

  const attributeKeywords = {
    'cuerpo': ['forzar', 'pelear'],
    'agudeza': ['escuchar', 'investigar'],
  };

  const intentKeywords = {
    'force': ['forzar', 'romper'],
    'investigate': ['escuchar', 'investigar', 'revisar'],
    'persuade': ['convencer', 'suplicar'],
  };

  const riskKeywords = {
    'high': ['a ciegas', 'sin cobertura'],
    'low': ['con cuidado', 'a salvo'],
  };

  const selfGrantPatterns = ['me otorgo', 'me convierto en', 'obtengo el rango'];

  group('ClassifyFreeAction', () {
    test('classifies intent by keyword vote', () {
      final result = classify(
        action: 'Intento forzar la puerta',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        intentKeywords: intentKeywords,
      );
      expect(result.intent, ActionIntent.force);
      expect(result.attributeKey, 'cuerpo');
    });

    test('defaults intent to investigate when nothing matches', () {
      final result = classify(
        action: 'Me quedo en silencio observando',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        intentKeywords: intentKeywords,
      );
      expect(result.intent, ActionIntent.investigate);
    });

    test('classifies risk by keyword vote, defaulting to standard', () {
      final risky = classify(
        action: 'Salto al vacío a ciegas',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        riskKeywords: riskKeywords,
      );
      expect(risky.risk, RiskLevel.high);

      final normal = classify(
        action: 'Camino por el sendero',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        riskKeywords: riskKeywords,
      );
      expect(normal.risk, RiskLevel.standard);
    });

    test('flags a self-granting attempt as invalid canon compatibility', () {
      final result = classify(
        action: 'Me otorgo el rango de gran maestro',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        selfGrantPatterns: selfGrantPatterns,
      );
      expect(result.canonCompatibility, CanonCompatibility.invalid);
    });

    test('a normal action is valid canon compatibility', () {
      final result = classify(
        action: 'Investigo el archivo de la lluvia',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        selfGrantPatterns: selfGrantPatterns,
      );
      expect(result.canonCompatibility, CanonCompatibility.valid);
    });

    test('targetId is null when no npc aliases are declared', () {
      final result = classify(
        action: 'Hablo con Qiao Wen',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
      );
      expect(result.targetId, isNull);
    });

    test('targetId resolves via knownNpcAliases keyword-vote', () {
      const knownNpcAliases = {
        'lian_suyin': ['suyin', 'la calígrafa'],
        'qiao_wen': ['qiao', 'qiao wen', 'el inspector'],
      };

      final result = classify(
        action: 'Le pregunto a Qiao Wen por el sello',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        knownNpcAliases: knownNpcAliases,
      );
      expect(result.targetId, 'qiao_wen');

      final other = classify(
        action: 'Busco a la calígrafa',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        knownNpcAliases: knownNpcAliases,
      );
      expect(other.targetId, 'lian_suyin');
    });

    test('targetId is null when the text mentions no known alias', () {
      final result = classify(
        action: 'Miro el río en silencio',
        attributeKeywords: attributeKeywords,
        fallbackAttribute: 'espiritu',
        knownNpcAliases: const {
          'qiao_wen': ['qiao'],
        },
      );
      expect(result.targetId, isNull);
    });
  });

  group('ActionIntent wire mapping', () {
    test('round-trips every intent through its wire name', () {
      for (final intent in ActionIntent.values) {
        expect(ActionIntent.fromWire(intent.wireName), intent);
      }
    });

    test('returns null for an unrecognised wire value', () {
      expect(ActionIntent.fromWire('teleport'), isNull);
    });
  });

  group('RiskLevel.fromWire', () {
    test('defaults to standard for an unrecognised value', () {
      expect(RiskLevel.fromWire('nonsense'), RiskLevel.standard);
      expect(RiskLevel.fromWire(null), RiskLevel.standard);
    });
  });
}
