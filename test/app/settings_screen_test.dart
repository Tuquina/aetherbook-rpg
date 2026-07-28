import 'package:aetherbook/adapters/auth/fake_auth_adapter.dart';
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/adapters/settings/fake_settings_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/onboarding_screen.dart';
import 'package:aetherbook/app/settings_screen.dart';
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
        name: 'Mundo',
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

Future<(FakeAuthAdapter, FakeSettingsAdapter, GameController)> _pumpSettings(
    WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final auth = FakeAuthAdapter(anonymous: false, email: 'jugador@aetherbook.dev');
  final settingsPort = FakeSettingsAdapter();
  final controller = _newController();
  await tester.pumpWidget(MaterialApp(
    home: SettingsScreen(controller: controller, settingsPort: settingsPort, authPort: auth),
  ));
  await tester.pump();
  return (auth, settingsPort, controller);
}

void main() {
  group('SettingsScreen', () {
    testWidgets('shows every section and control from the mockup', (tester) async {
      await _pumpSettings(tester);

      expect(find.text('Cómo se lee'), findsOneWidget);
      expect(find.text('Cómo narra'), findsOneWidget);
      expect(find.text('Límites'), findsOneWidget);
      expect(find.text('Tamaño del texto'), findsOneWidget);
      expect(find.text('Aparecer el texto letra a letra'), findsOneWidget);
      expect(find.text('Ilustrar las escenas'), findsOneWidget);
      expect(find.text('Dureza del mundo'), findsOneWidget);
      expect(find.text('Sugerir acciones'), findsOneWidget);
      expect(find.text('Mostrar la tirada'), findsOneWidget);
      expect(find.text('Temas que el narrador evita'), findsOneWidget);
      expect(find.text('Recordarme un tomo abierto'), findsOneWidget);
      expect(find.text('Volver a ver cómo se juega'), findsOneWidget);
      expect(find.text('Ver la introducción otra vez'), findsOneWidget);
      expect(find.text('Exportar mis tomos'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets(
        '"Ver la introducción otra vez" replays onboarding and pops back to Ajustes when done, '
        'even though hasSeenOnboarding is already true', (tester) async {
      await _pumpSettings(tester);

      await tester.tap(find.text('Ver la introducción otra vez'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(SettingsScreen), findsNothing); // covered by the pushed route

      await tester.tap(find.text('Saltar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('toggling "Ilustrar las escenas" updates the controller and saves',
        (tester) async {
      final (_, settingsPort, controller) = await _pumpSettings(tester);
      expect(controller.settings.illustrateScenes, isTrue);

      await tester.tap(find.text('Ilustrar las escenas'));
      await tester.pump();

      expect(controller.settings.illustrateScenes, isFalse);
      expect(settingsPort.saveSettingsCalls.last.illustrateScenes, isFalse);
    });

    testWidgets('tapping a harshness chip updates worldHarshness', (tester) async {
      final (_, _, controller) = await _pumpSettings(tester);
      expect(controller.settings.worldHarshness, WorldHarshness.justo);

      await tester.tap(find.text('Cruel'));
      await tester.pump();

      expect(controller.settings.worldHarshness, WorldHarshness.cruel);
    });

    testWidgets('"Cerrar sesión" signs out and pops back to the navigation root',
        (tester) async {
      final (auth, _, controller) = await _pumpSettings(tester);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();

      expect(auth.signOutCalls, 1);
      expect(auth.isAnonymous, isTrue);
    });
  });
}
