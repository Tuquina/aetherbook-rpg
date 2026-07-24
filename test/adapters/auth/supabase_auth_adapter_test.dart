import 'package:aetherbook/adapters/auth/supabase_auth_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('isEmailAlreadyTakenError', () {
    test('true for the email_exists error code', () {
      const e = AuthApiException('Email already registered', code: 'email_exists');
      expect(isEmailAlreadyTakenError(e), isTrue);
    });

    test('true for the user_already_exists error code', () {
      const e = AuthApiException('User already exists', code: 'user_already_exists');
      expect(isEmailAlreadyTakenError(e), isTrue);
    });

    test('true when there is no code but the message says "already"', () {
      const e = AuthApiException('A user with this email address has already been registered');
      expect(isEmailAlreadyTakenError(e), isTrue);
    });

    test('false for an unrelated error, so it propagates instead of masking it', () {
      const e = AuthApiException('Network request failed', code: 'unexpected_failure');
      expect(isEmailAlreadyTakenError(e), isFalse);
    });
  });
}
