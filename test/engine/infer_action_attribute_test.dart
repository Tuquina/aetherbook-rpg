import 'package:aetherbook/core/engine/infer_action_attribute.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const infer = InferActionAttribute();

  const keywords = {
    'cuerpo': ['forzar', 'pelear', 'escalar', 'cargar', 'empujar'],
    'mente': ['leer', 'recordar', 'descifrar', 'estudiar', 'planificar'],
    'espiritu': ['meditar', 'sentir', 'invocar', 'rezar', 'percibir'],
  };

  group('InferActionAttribute', () {
    test('matches a single keyword to its attribute', () {
      final result = infer(
        action: 'Intento forzar la puerta',
        attributeKeywords: keywords,
        fallback: 'espiritu',
      );
      expect(result, 'cuerpo');
    });

    test('is case-insensitive', () {
      final result = infer(
        action: 'FORZAR la reja con fuerza bruta',
        attributeKeywords: keywords,
        fallback: 'espiritu',
      );
      expect(result, 'cuerpo');
    });

    test('matches a different world attribute for different action text', () {
      final result = infer(
        action: 'Leer el manuscrito antiguo',
        attributeKeywords: keywords,
        fallback: 'espiritu',
      );
      expect(result, 'mente');
    });

    test('falls back when no keyword matches', () {
      final result = infer(
        action: 'Saludar cordialmente al anciano',
        attributeKeywords: keywords,
        fallback: 'espiritu',
      );
      expect(result, 'espiritu');
    });

    test('falls back when attributeKeywords is empty', () {
      final result = infer(
        action: 'Cualquier acción',
        attributeKeywords: const {},
        fallback: 'espiritu',
      );
      expect(result, 'espiritu');
    });

    test('picks the attribute with the most keyword hits', () {
      // "recordar" (mente) is one hit; "sentir" + "meditar" (espiritu) are two.
      final result = infer(
        action: 'Sentir el flujo del qi mientras intento recordar y meditar',
        attributeKeywords: keywords,
        fallback: 'cuerpo',
      );
      expect(result, 'espiritu');
    });

    test('matches a keyword embedded inside a longer word', () {
      // "cargar" is a substring of "descargar" — deliberately a simple
      // substring match, not word-boundary aware; documents the current,
      // pragmatic behavior.
      final result = infer(
        action: 'Intento descargar el peso de mis hombros',
        attributeKeywords: keywords,
        fallback: 'espiritu',
      );
      expect(result, 'cuerpo');
    });
  });
}
