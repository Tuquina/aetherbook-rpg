// V2: there is no anonymous/guest path anymore — "Comenzar" routes to
// AccountScreen first when there's no real account yet, and only continues
// to WorldSelectScreen once AuthPort reports one (directly, or via the
// degraded in-memory mode where there's no account system to gate on).
import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/adapters/settings/fake_settings_adapter.dart';
import 'package:aetherbook/app/account_screen.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/onboarding_screen.dart';
import 'package:aetherbook/app/splash_screen.dart';
import 'package:aetherbook/app/world_select_screen.dart';
import 'package:aetherbook/core/settings/user_settings.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => World(
        slug: slug,
        name: 'Mundo $slug',
        theme: slug,
        tone: 'neutro',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'voluntad',
        startingCharacter: const Character(
            name: 'Protagonista', level: 1, exp: 0, attributes: {}, resources: {}),
        seedNarration: '',
        seedChoices: const [],
      );
}

GameController _newController({FakeSettingsAdapter? settingsPort}) => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
      settingsPort: settingsPort,
    );

void main() {
  testWidgets('shows no "seguir sin cuenta" affordance anywhere on the splash',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(controller: _newController(), auth: FakeAuthAdapter()),
    ));
    await tester.pump();

    expect(find.textContaining('sin cuenta'), findsNothing);
  });

  testWidgets('"Comenzar" routes to AccountScreen when there is no account yet',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(controller: _newController(), auth: FakeAuthAdapter()),
    ));
    await tester.pump();

    await tester.tap(find.text('Comenzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.byType(WorldSelectScreen), findsNothing);
  });

  testWidgets('"Comenzar" goes straight to WorldSelectScreen when already authenticated',
      (tester) async {
    final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(controller: _newController(), auth: auth),
    ));
    await tester.pump();

    await tester.tap(find.text('Comenzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldSelectScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
  });

  testWidgets('"Comenzar" plays in-memory (no gate) when auth is null — degraded mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(controller: _newController(), auth: null),
    ));
    await tester.pump();

    await tester.tap(find.text('Comenzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldSelectScreen), findsOneWidget);
  });

  testWidgets('completing sign-in on the forced AccountScreen continues to WorldSelectScreen',
      (tester) async {
    final auth = FakeAuthAdapter();
    await tester.pumpWidget(MaterialApp(
      home: SplashScreen(controller: _newController(), auth: auth),
    ));
    await tester.pump();

    await tester.tap(find.text('Comenzar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(WorldSelectScreen), findsOneWidget);
    expect(find.byType(AccountScreen), findsNothing);
  });

  group('onboarding gate (V2 §6c-e, settingsPort configured)', () {
    testWidgets('a freshly signed-in account that has never seen onboarding is routed there',
        (tester) async {
      final auth = FakeAuthAdapter();
      final settingsPort = FakeSettingsAdapter();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(controller: _newController(settingsPort: settingsPort), auth: auth),
      ));
      await tester.pump();

      await tester.tap(find.text('Comenzar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AccountScreen), findsOneWidget);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(WorldSelectScreen), findsNothing);
    });

    testWidgets(
        'an already-signed-in account that already saw onboarding goes straight to WorldSelectScreen',
        (tester) async {
      final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
      final settingsPort =
          FakeSettingsAdapter(seeded: const UserSettings(hasSeenOnboarding: true));
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(controller: _newController(settingsPort: settingsPort), auth: auth),
      ));
      await tester.pump();

      await tester.tap(find.text('Comenzar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WorldSelectScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets(
        'an already-signed-in account that never finished onboarding still gets routed there '
        '(closed the app mid-onboarding on a previous launch)', (tester) async {
      final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
      final settingsPort = FakeSettingsAdapter(); // hasSeenOnboarding: false by default
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(controller: _newController(settingsPort: settingsPort), auth: auth),
      ));
      await tester.pump();

      await tester.tap(find.text('Comenzar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('finishing onboarding by choosing a card lands on WorldSelectScreen',
        (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
      final settingsPort = FakeSettingsAdapter();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(controller: _newController(settingsPort: settingsPort), auth: auth),
      ));
      await tester.pump();
      await tester.tap(find.text('Comenzar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('Sigue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Sigue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Una historia completa'), findsOneWidget);

      await tester.tap(find.text('Una historia completa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WorldSelectScreen), findsOneWidget);
      expect(settingsPort.saveSettingsCalls.last.hasSeenOnboarding, isTrue);
    });

    testWidgets('skipping onboarding also marks it seen and lands on WorldSelectScreen',
        (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
      final settingsPort = FakeSettingsAdapter();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(controller: _newController(settingsPort: settingsPort), auth: auth),
      ));
      await tester.pump();
      await tester.tap(find.text('Comenzar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await tester.tap(find.text('Saltar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(WorldSelectScreen), findsOneWidget);
      expect(settingsPort.saveSettingsCalls.last.hasSeenOnboarding, isTrue);
    });
  });
}
