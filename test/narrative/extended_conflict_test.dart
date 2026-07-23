import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conflict = ExtendedConflict(successesRequired: 2, failuresAllowed: 2);

  group('ExtendedConflict.recordAttempt / outcomeFor', () {
    test('is undecided while below both thresholds', () {
      var progress = const ExtendedConflictProgress();
      progress = conflict.recordAttempt(
        progress,
        attributeKey: 'espiritu',
        succeeded: true,
      );
      expect(progress.successes, 1);
      expect(conflict.outcomeFor(progress), isNull);
    });

    test('resolves as succeeded on reaching successesRequired', () {
      var progress = const ExtendedConflictProgress();
      progress = conflict.recordAttempt(progress, attributeKey: 'espiritu', succeeded: true);
      progress = conflict.recordAttempt(progress, attributeKey: 'agudeza', succeeded: true);
      expect(conflict.outcomeFor(progress), ConflictOutcome.succeeded);
    });

    test('resolves as failedForward on reaching failuresAllowed, even mid-successes', () {
      var progress = const ExtendedConflictProgress();
      progress = conflict.recordAttempt(progress, attributeKey: 'espiritu', succeeded: true);
      progress = conflict.recordAttempt(progress, attributeKey: 'agudeza', succeeded: false);
      progress = conflict.recordAttempt(progress, attributeKey: 'cuerpo', succeeded: false);
      expect(progress.successes, 1);
      expect(progress.failures, 2);
      expect(conflict.outcomeFor(progress), ConflictOutcome.failedForward);
    });

    test('whichever threshold is hit first decides the outcome', () {
      // 2 successes reached before a 2nd failure -> succeeded, even though a
      // failure happened along the way.
      var progress = const ExtendedConflictProgress();
      progress = conflict.recordAttempt(progress, attributeKey: 'a', succeeded: false);
      progress = conflict.recordAttempt(progress, attributeKey: 'b', succeeded: true);
      progress = conflict.recordAttempt(progress, attributeKey: 'c', succeeded: true);
      expect(conflict.outcomeFor(progress), ConflictOutcome.succeeded);
    });
  });

  group('ExtendedConflict.modifierFor', () {
    test('no penalty when the attribute differs from the last attempt', () {
      const progress = ExtendedConflictProgress(lastAttributeKey: 'espiritu');
      expect(conflict.modifierFor(progress, 'agudeza'), 0);
    });

    test('applies the repeat-attribute penalty when repeating the last attribute', () {
      const progress = ExtendedConflictProgress(lastAttributeKey: 'espiritu');
      expect(conflict.modifierFor(progress, 'espiritu'), -2);
    });

    test('no penalty on the very first attempt (no last attribute yet)', () {
      const progress = ExtendedConflictProgress();
      expect(conflict.modifierFor(progress, 'espiritu'), 0);
    });

    test('the penalty amount is configurable', () {
      const custom = ExtendedConflict(
        successesRequired: 3,
        failuresAllowed: 2,
        repeatAttributePenalty: -4,
      );
      const progress = ExtendedConflictProgress(lastAttributeKey: 'cuerpo');
      expect(custom.modifierFor(progress, 'cuerpo'), -4);
    });
  });

  group('ExtendedConflict.fromJson', () {
    test('parses the campaign-bible §6.12 shape', () {
      final parsed = ExtendedConflict.fromJson({
        'successes_required': 3,
        'failures_allowed': 2,
        'repeat_attribute_penalty': -2,
      });
      expect(parsed.successesRequired, 3);
      expect(parsed.failuresAllowed, 2);
      expect(parsed.repeatAttributePenalty, -2);
    });

    test('defaults repeat_attribute_penalty to -2 when omitted', () {
      final parsed = ExtendedConflict.fromJson({
        'successes_required': 2,
        'failures_allowed': 2,
      });
      expect(parsed.repeatAttributePenalty, -2);
    });
  });
}
