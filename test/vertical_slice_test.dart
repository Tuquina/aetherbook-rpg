// Plays the campaign-bible §23.1 vertical slice end-to-end through the real
// GameScreen UI, against the *real* xianxia_lianshu.json content (loaded the
// same way test/content/xianxia_lianshu_test.dart does — dart:io File, not
// rootBundle, matching widget_test.dart's own choice to avoid touching asset
// bundles in a widget test) and a FakeNarratorAdapter. FixedDice(20) makes
// every check a natural 20 (always a critical success regardless of
// modifiers — CLAUDE.md/ResolvePlayerAction's rule), so the slice can be
// driven deterministically through chargen -> p1 -> p2 -> c1_n01 -> c1_n02
// -> c1_n03 and into the start of Chapter II.
import 'dart:convert';
import 'dart:io';

import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/app/game_screen.dart';
import 'package:aetherbook/core/engine/create_character.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

World _loadXianxiaLianshu() {
  final raw = File('assets/worlds/xianxia_lianshu.json').readAsStringSync();
  return World.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class _RealContentWorldRepository implements WorldRepositoryPort {
  @override
  Future<World> loadWorld(String slug) async => _loadXianxiaLianshu();
}

Future<void> _tapAndSettle(WidgetTester tester, String label) async {
  // GameScreen hides the choices bar behind a "seguí leyendo" hint until the
  // player scrolls through the current turn's prose (mobile UX: no tapping
  // past text you haven't read) -- scroll to the end first so it unlocks,
  // same as a real reader would before finding the button. pumpAndSettle
  // (rather than fixed-duration pumps) rides out the scroll-to-top animation
  // GameScreen fires on every new turn, whatever its actual duration.
  await tester.drag(find.byKey(const Key('narrationScroll')), const Offset(0, -10000));
  await tester.pumpAndSettle();

  expect(find.text(label), findsOneWidget, reason: 'expected a "$label" button on screen');
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'plays the recommended vertical slice end-to-end '
    '(chargen -> p1 -> p2 -> c1_n01 -> c1_n02 -> c1_n03)',
    (tester) async {
      final controller = GameController(
        worldRepository: _RealContentWorldRepository(),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(20), // natural 20 -> always a critical success
      );

      // Chargen (p0_creacion) happens via CreateCharacter, same as
      // ChargenScreen would produce — this test drives GameScreen directly
      // rather than through the Splash/Chargen navigation flow.
      await controller.start(
        'xianxia_lianshu',
        chargenInput: const CreateCharacterInput(
          name: 'Protagonista de prueba',
          originId: 'discipulo_expulsado',
          freeAttributePoint: 'presencia',
          vowId: 'nadie_me_posee',
        ),
      );

      await tester.pumpWidget(MaterialApp(home: GameScreen(controller: controller)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // p1_barca_funeraria: the literal, pre-written opening prose is shown
      // verbatim, no narrator call needed for the entry itself.
      expect(find.textContaining('Primero vuelve el frío'), findsOneWidget);
      expect(controller.currentNode!.id, 'p1_barca_funeraria');

      await _tapAndSettle(tester, 'Empujar la tapa antes de que la barca llegue a la compuerta');
      expect(controller.currentNode!.id, 'p2_bajo_el_puente');

      await _tapAndSettle(tester, 'Primero quiero recuperar mi nombre.');
      expect(controller.currentNode!.id, 'c1_n01_casa_de_tinta');

      // Exercise a hub activity: applies its effect (here, a no-op — the
      // character starts at qi's formula ceiling right out of chargen, so
      // meditating has nothing to restore) without leaving the hub.
      await _tapAndSettle(tester, 'Meditar con Huo Zhen');
      expect(controller.currentNode!.id, 'c1_n01_casa_de_tinta');

      await _tapAndSettle(tester, 'Ir a la Torre de las Campanas');
      expect(controller.currentNode!.id, 'c1_n02_buscar_acceso');

      await _tapAndSettle(tester, 'Deducir la contraseña del antiguo registrador');
      expect(controller.currentNode!.id, 'c1_n03_coro_en_el_campanario');
      expect(find.textContaining('cometas blancas'), findsOneWidget);

      // c1_n03 is an extended conflict (2 successes before 2 failures) — one
      // critical success isn't enough to leave yet.
      await _tapAndSettle(tester, 'Contener su forma');
      expect(controller.currentNode!.id, 'c1_n03_coro_en_el_campanario');

      // A second success (different attribute) decides the conflict.
      await _tapAndSettle(tester, 'Escuchar las voces');
      expect(controller.currentNode!.id, 'c2_n01_entrada_al_pabellon');

      expect(controller.error, isNull);
    },
  );
}
