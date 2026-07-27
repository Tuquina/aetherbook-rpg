import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:aetherbook/app/account_screen.dart';
import 'package:aetherbook/ports/auth_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixed-duration pump() calls, not pumpAndSettle(): AetherBackground runs an
// indefinitely-repeating ambient animation by default (atmosphere.dart),
// which pumpAndSettle can never consider "settled" — same reason
// widget_test.dart avoids it for GameScreen.
//
// AccountScreen's sign-up form (Google button + divider + title + body copy
// + 2 fields + hint + submit + link) is a long ListView -- a Sliver only
// builds elements near its viewport, so the submit button and password
// field may not exist in the tree at all at the default 800x600 test
// surface (same gotcha chargen_screen_test.dart hit and fixed).
Future<void> _pumpAccountScreen(WidgetTester tester, AuthPort auth) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: AccountScreen(authPort: auth)));
  await tester.pump();
}

Future<void> _enterEmailAndPassword(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), email);
  await tester.pump();
  await tester.enterText(fields.at(1), password);
  await tester.pump();
}

void main() {
  group('AccountScreen — sign-up (default view)', () {
    testWidgets('shows Google + email/password form while anonymous', (tester) async {
      await _pumpAccountScreen(tester, FakeAuthAdapter());

      expect(find.text('Guarda tu progreso'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('¿Ya tienes cuenta? Entrar'), findsOneWidget);
    });

    testWidgets('shows the linked state directly when already signed in',
        (tester) async {
      await _pumpAccountScreen(
        tester,
        FakeAuthAdapter(anonymous: false, email: 'vieja@aetherbook.dev'),
      );

      expect(find.text('Ya estás guardando tu progreso'), findsOneWidget);
      expect(find.textContaining('vieja@aetherbook.dev'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsNothing);
    });

    testWidgets('the submit button stays disabled for an invalid email or short password',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await _enterEmailAndPassword(tester, email: 'no-arroba', password: 'short');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();

      expect(auth.signUpWithPasswordCalls, isEmpty);
    });

    testWidgets('a successful sign-up shows the "revisa tu correo" confirmation',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await _enterEmailAndPassword(
          tester, email: 'nueva@aetherbook.dev', password: 'contrasena123');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();

      expect(auth.signUpWithPasswordCalls, [
        (email: 'nueva@aetherbook.dev', password: 'contrasena123'),
      ]);
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.textContaining('nueva@aetherbook.dev'), findsOneWidget);
      // isAnonymous doesn't flip until the emailed link is confirmed.
      expect(auth.isAnonymous, isTrue);
    });

    testWidgets('an email already registered shows the merge warning, not a generic error',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await _enterEmailAndPassword(
          tester, email: 'vieja@aetherbook.dev', password: 'contrasena123');
      auth.nextError = const EmailAlreadyRegisteredException('vieja@aetherbook.dev');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();

      expect(find.text('Ese correo ya tiene cuenta'), findsOneWidget);
      expect(find.text('Entrar con ese email'), findsOneWidget);
    });

    testWidgets('tapping the merge-warning link switches to the sign-in form',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await _enterEmailAndPassword(
          tester, email: 'vieja@aetherbook.dev', password: 'contrasena123');
      auth.nextError = const EmailAlreadyRegisteredException('vieja@aetherbook.dev');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();

      await tester.tap(find.text('Entrar con ese email'));
      await tester.pump();

      expect(find.text('Llévate tus tomos a cualquier sitio'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('a failed sign-up shows an inline error and stays on the form',
        (tester) async {
      final auth = FakeAuthAdapter()..nextError = Exception('network down');
      await _pumpAccountScreen(tester, auth);

      await _enterEmailAndPassword(
          tester, email: 'nueva@aetherbook.dev', password: 'contrasena123');
      await tester.tap(find.text('Crear cuenta'));
      await tester.pump();

      expect(find.textContaining('No pudimos crear la cuenta'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });
  });

  group('AccountScreen — Google', () {
    testWidgets('tapping the Google button links the current session', (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pump();

      expect(auth.signInWithGoogleCalls, hasLength(1));
    });

    testWidgets('once onChange fires (link completed), the screen shows the linked state',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pump();

      expect(find.text('Ya estás guardando tu progreso'), findsOneWidget);
      expect(auth.isAnonymous, isFalse);
    });

    testWidgets('a failed Google link shows an inline error', (tester) async {
      final auth = FakeAuthAdapter()..nextError = Exception('popup closed');
      await _pumpAccountScreen(tester, auth);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pump();

      expect(find.textContaining('No pudimos conectar con Google'), findsOneWidget);
    });
  });

  group('AccountScreen — sign-in', () {
    Future<void> goToSignIn(WidgetTester tester, FakeAuthAdapter auth) async {
      await _pumpAccountScreen(tester, auth);
      await tester.tap(find.text('¿Ya tienes cuenta? Entrar'));
      await tester.pump();
    }

    testWidgets('a successful sign-in switches to the linked state', (tester) async {
      final auth = FakeAuthAdapter();
      await goToSignIn(tester, auth);

      await _enterEmailAndPassword(
          tester, email: 'vieja@aetherbook.dev', password: 'contrasena123');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(auth.signInWithPasswordCalls, [
        (email: 'vieja@aetherbook.dev', password: 'contrasena123'),
      ]);
      expect(find.text('Ya estás guardando tu progreso'), findsOneWidget);
    });

    testWidgets('a failed sign-in never reveals whether the email or the password was wrong',
        (tester) async {
      final auth = FakeAuthAdapter()..nextError = Exception('Invalid login credentials');
      await goToSignIn(tester, auth);

      await _enterEmailAndPassword(
          tester, email: 'vieja@aetherbook.dev', password: 'wrong-password');
      await tester.tap(find.text('Entrar'));
      await tester.pump();

      expect(find.textContaining('No pudimos iniciar sesión'), findsOneWidget);
      expect(find.textContaining('Invalid login credentials'), findsNothing);
    });

    testWidgets('has a link back to sign-up and to forgot-password', (tester) async {
      final auth = FakeAuthAdapter();
      await goToSignIn(tester, auth);

      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
      expect(find.text('¿No tienes cuenta? Crear una'), findsOneWidget);
    });
  });

  group('AccountScreen — forgot password', () {
    testWidgets('sending a reset link always shows the same neutral confirmation',
        (tester) async {
      final auth = FakeAuthAdapter();
      await _pumpAccountScreen(tester, auth);
      await tester.tap(find.text('¿Ya tienes cuenta? Entrar'));
      await tester.pump();
      await tester.tap(find.text('Olvidé mi contraseña'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'cualquiera@aetherbook.dev');
      await tester.pump();
      await tester.tap(find.text('Enviar enlace'));
      await tester.pump();

      expect(auth.resetPasswordCalls, ['cualquiera@aetherbook.dev']);
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(
        find.textContaining('Si hay una cuenta con ese correo'),
        findsOneWidget,
      );
    });
  });
}
