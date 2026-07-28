// V2: there is no anonymous/guest path anymore — "Comenzar" routes to
// AccountScreen first when there's no real account yet, and only continues
// to WorldSelectScreen once AuthPort reports one (directly, or via the
// degraded in-memory mode where there's no account system to gate on).
import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/account_screen.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/splash_screen.dart';
import 'package:aetherbook/app/world_select_screen.dart';
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

GameController _newController() => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const FakeNarratorAdapter(latency: Duration.zero),
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
}
