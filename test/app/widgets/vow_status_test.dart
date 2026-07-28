import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/app/widgets/vow_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveVowStatus', () {
    test('roto', () {
      final r = resolveVowStatus('roto', 3);
      expect(r.color, AetherColors.failure);
      expect(r.icon, Icons.warning_rounded);
      expect(r.label, 'Roto');
    });

    test('sostenido', () {
      final r = resolveVowStatus('sostenido', 0);
      expect(r.color, AetherColors.success);
      expect(r.icon, Icons.check_circle_rounded);
      expect(r.label, 'Sostenido hasta el final');
    });

    test('puesto_a_prueba, singular vs plural phrasing', () {
      expect(resolveVowStatus('puesto_a_prueba', 1).label, 'Puesto a prueba una vez');
      expect(resolveVowStatus('puesto_a_prueba', 2).label, 'Puesto a prueba 2 veces');
    });

    test('null (never tested) resolves to "Intacto", not "puesto a prueba 0 veces" '
        '— the bug both previous copies of this switch had', () {
      final r = resolveVowStatus(null, 0);
      expect(r.label, 'Intacto');
      expect(r.label, isNot(contains('Puesto a prueba')));
      expect(r.color, isNot(AetherColors.failure));
    });
  });
}
