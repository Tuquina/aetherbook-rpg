import 'package:aetherbook/core/world/resource_formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ResourceFormula.evaluate', () {
    test('evaluates base plus a single attribute coefficient', () {
      // "8 + (cuerpo * 2)" from the campaign-bible format.
      const formula = ResourceFormula(base: 8, perAttribute: {'cuerpo': 2});
      expect(formula.evaluate({'cuerpo': 3}), 14);
    });

    test('sums multiple attribute coefficients', () {
      const formula = ResourceFormula(
        base: 4,
        perAttribute: {'espiritu': 2, 'agudeza': 1},
      );
      expect(formula.evaluate({'espiritu': 3, 'agudeza': 2}), 4 + 6 + 2);
    });

    test('treats a missing attribute as zero', () {
      const formula = ResourceFormula(base: 10, perAttribute: {'cuerpo': 2});
      expect(formula.evaluate(const {}), 10);
    });

    test('a formula with no coefficients is just the base', () {
      const formula = ResourceFormula(base: 20);
      expect(formula.evaluate({'cuerpo': 99}), 20);
    });
  });

  group('ResourceFormula.fromJson', () {
    test('a flat number is a base-only formula (simple worlds)', () {
      final formula = ResourceFormula.fromJson(20);
      expect(formula.base, 20);
      expect(formula.perAttribute, isEmpty);
      expect(formula.evaluate({'cuerpo': 5}), 20);
    });

    test('parses a structured base + per_attribute object', () {
      final formula = ResourceFormula.fromJson({
        'base': 8,
        'per_attribute': {'cuerpo': 2},
      });
      expect(formula.evaluate({'cuerpo': 3}), 14);
    });

    test('defaults to a zero formula for null or unrecognized input', () {
      expect(ResourceFormula.fromJson(null).evaluate(const {}), 0);
      expect(ResourceFormula.fromJson('nonsense').evaluate(const {}), 0);
    });
  });
}
