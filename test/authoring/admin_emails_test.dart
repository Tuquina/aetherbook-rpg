import 'package:aetherbook/core/authoring/admin_emails.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAdminEmail', () {
    test('recognizes every address on the allowlist', () {
      for (final email in adminEmails) {
        expect(isAdminEmail(email), isTrue, reason: email);
      }
    });

    test('is false for an unlisted email', () {
      expect(isAdminEmail('nobody@example.com'), isFalse);
    });

    test('is false for null (anonymous/unauthenticated)', () {
      expect(isAdminEmail(null), isFalse);
    });

    test('the fixed 5-address roster requested for the editor', () {
      expect(adminEmails, {
        'carrizoaagustin@gmail.com',
        'fernandotuquina@gmail.com',
        'franjaime2016@gmail.com',
        'francoq96@gmail.com',
        'aetherbook.app@gmail.com',
      });
    });
  });
}
