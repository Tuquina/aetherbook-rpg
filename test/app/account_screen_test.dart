import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:aetherbook/app/account_screen.dart';
import 'package:aetherbook/ports/auth_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixed-duration pump() calls, not pumpAndSettle(): AetherBackground runs an
// indefinitely-repeating ambient animation by default (atmosphere.dart),
// which pumpAndSettle can never consider "settled" — same reason
// widget_test.dart avoids it for GameScreen.
Future<void> _pumpAccountScreen(WidgetTester tester, AuthPort auth) async {
  await tester.pumpWidget(MaterialApp(home: AccountScreen(authPort: auth)));
  await tester.pump();
}

void main() {
  group('AccountScreen', () {
    testWidgets('shows the form and a disabled button while anonymous', (tester) async {
      await _pumpAccountScreen(tester, FakeAuthAdapter());

      expect(find.text('Guardá tu progreso'), findsOneWidget);
      expect(find.text('Enviar enlace'), findsOneWidget);
    });

    testWidgets('shows the linked state directly when already signed in with email',
        (tester) async {
      await _pumpAccountScreen(
        tester,
        FakeAuthAdapter(anonymous: false, email: 'vieja@aetherbook.dev'),
      );

      expect(find.text('Ya estás guardando tu progreso'), findsOneWidget);
      expect(find.textContaining('vieja@aetherbook.dev'), findsOneWidget);
      expect(find.text('Enviar enlace'), findsNothing);
    });

    testWidgets('submitting a new email shows the "revisá tu correo" confirmation',
        (tester) async {
      final auth = FakeAuthAdapter()..nextOutcome = EmailLinkOutcome.linkConfirmationSent;
      await _pumpAccountScreen(tester, auth);

      await tester.enterText(find.byType(TextField), 'nueva@aetherbook.dev');
      await tester.pump();
      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();

      expect(auth.continueWithEmailCalls, ['nueva@aetherbook.dev']);
      expect(find.text('Revisá tu correo'), findsOneWidget);
      expect(find.textContaining('nueva@aetherbook.dev'), findsOneWidget);
    });

    testWidgets('submitting an email that already has an account explains the sign-in link '
        'instead', (tester) async {
      final auth = FakeAuthAdapter()..nextOutcome = EmailLinkOutcome.signInLinkSent;
      await _pumpAccountScreen(tester, auth);

      await tester.enterText(find.byType(TextField), 'vieja@aetherbook.dev');
      await tester.pump();
      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();

      expect(find.textContaining('ya tiene una cuenta'), findsOneWidget);
    });

    testWidgets('a failed send shows an inline error and stays on the form', (tester) async {
      final auth = FakeAuthAdapter()..nextError = Exception('network down');
      await _pumpAccountScreen(tester, auth);

      await tester.enterText(find.byType(TextField), 'nueva@aetherbook.dev');
      await tester.pump();
      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();

      expect(find.textContaining('No pudimos enviar el correo'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the submit button stays disabled for an obviously invalid email',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await tester.enterText(find.byType(TextField), 'no-arroba');
      await tester.pump();
      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();

      // The disabled button ignored the tap — no submission went through.
      expect(auth.continueWithEmailCalls, isEmpty);
      expect(find.text('Guardá tu progreso'), findsOneWidget);
    });
  });
}
