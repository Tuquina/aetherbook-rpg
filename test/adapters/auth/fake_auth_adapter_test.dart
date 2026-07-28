import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAuthAdapter.signOut', () {
    test('becomes anonymous again and clears the email', () async {
      final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');

      await auth.signOut();

      expect(auth.isAnonymous, isTrue);
      expect(auth.email, isNull);
      expect(auth.signOutCalls, 1);
    });

    test('fires onChange so listeners can react', () async {
      final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
      var changeCount = 0;
      final sub = auth.onChange.listen((_) => changeCount++);

      await auth.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(changeCount, 1);
      await sub.cancel();
    });
  });
}
