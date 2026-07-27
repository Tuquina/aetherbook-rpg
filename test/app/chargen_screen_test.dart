// No widget test existed for ChargenScreen before this file. Covers the new
// V2 tone step (Stage 6c) specifically: hidden for a world with no `tones`,
// shown and optional for one that declares them, and threaded through to
// the created Character on confirm.
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/chargen_screen.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/character_origin.dart';
import 'package:aetherbook/core/world/tone_option.dart';
import 'package:aetherbook/core/world/vow.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _origins = [
  CharacterOrigin(
    id: 'convocado',
    displayName: 'Convocado',
    baseAttributes: {'ingenio': 2},
    tagId: 'convocado_tag',
  ),
];
const _vows = [Vow(id: 'volver', text: 'Voy a volver a casa.')];

World _worldWith({List<ToneOption> tones = const []}) => World(
      slug: 'isekai',
      name: 'Isekai',
      theme: 'isekai',
      tone: 'aventurero',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: 'ingenio',
      attributeKeys: const ['ingenio'],
      origins: _origins,
      vows: _vows,
      tones: tones,
      hasFreeAttributePoint: false,
      startingCharacter: const Character(
        name: 'Convocado', level: 1, exp: 0, attributes: {}, resources: {}),
      seedNarration: 'Comienza.',
      seedChoices: const ['Avanzar'],
    );

class _FakeWorldRepository implements WorldRepositoryPort {
  const _FakeWorldRepository(this.world);
  final World world;

  @override
  Future<World> loadWorld(String slug) async => world;
}

/// ChargenScreen is a long single-scroll form; a `ListView` only builds
/// elements near its viewport, so a widget far down (the tone step, the
/// confirm button) may not exist in the tree at all at the default
/// 800x600 test surface. A tall viewport avoids needing to scroll to it.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<GameController> _pumpChargen(WidgetTester tester, World world) async {
  _useTallViewport(tester);
  final controller = GameController(
    worldRepository: _FakeWorldRepository(world),
    narrator: const FakeNarratorAdapter(latency: Duration.zero),
    dice: const FixedDice(10),
  );
  await tester.pumpWidget(MaterialApp(
    home: ChargenScreen(controller: controller, worldSlug: world.slug, world: world),
  ));
  await tester.pump();
  return controller;
}

const _tones = [
  ToneOption(id: 'epico', label: 'Épico', blurb: 'Grande, mítico', previewText: 'El umbral te reclamó.'),
  ToneOption(id: 'acido', label: 'Ácido', blurb: 'Seco, irónico', previewText: 'El destino tiene humor pésimo.'),
];

void main() {
  group('ChargenScreen tone step (V2 Stage 6c)', () {
    testWidgets('is not shown at all for a world with no tones', (tester) async {
      await _pumpChargen(tester, _worldWith());

      expect(find.text('Tono de la narración (opcional)'), findsNothing);
    });

    testWidgets('shows every declared tone; tapping one reveals its preview',
        (tester) async {
      await _pumpChargen(tester, _worldWith(tones: _tones));

      expect(find.text('Tono de la narración (opcional)'), findsOneWidget);
      expect(find.text('Épico'), findsOneWidget);
      expect(find.text('Ácido'), findsOneWidget);
      expect(find.textContaining('El umbral te reclamó'), findsNothing);

      await tester.tap(find.text('Épico'));
      await tester.pump();

      expect(find.textContaining('El umbral te reclamó'), findsOneWidget);
    });

    testWidgets('tapping the selected tone again deselects it', (tester) async {
      await _pumpChargen(tester, _worldWith(tones: _tones));

      await tester.tap(find.text('Épico'));
      await tester.pump();
      expect(find.textContaining('El umbral te reclamó'), findsOneWidget);

      await tester.tap(find.text('Épico'));
      await tester.pump();
      expect(find.textContaining('El umbral te reclamó'), findsNothing);
    });

    testWidgets('confirming with a tone chosen threads it onto the created character',
        (tester) async {
      final controller = await _pumpChargen(tester, _worldWith(tones: _tones));

      await tester.enterText(find.byType(TextField).first, 'Yuki');
      await tester.tap(find.text('Convocado')); // the only origin
      await tester.pump();
      await tester.tap(find.text('Ácido'));
      await tester.pump();
      await tester.tap(find.text('"Voy a volver a casa."')); // the only vow
      await tester.pump();

      await tester.tap(find.text('Confirmar ficha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.character!.chosenTone, 'acido');
    });

    testWidgets('confirming without picking a tone leaves it null', (tester) async {
      final controller = await _pumpChargen(tester, _worldWith(tones: _tones));

      await tester.enterText(find.byType(TextField).first, 'Yuki');
      await tester.tap(find.text('Convocado'));
      await tester.pump();
      await tester.tap(find.text('"Voy a volver a casa."'));
      await tester.pump();

      await tester.tap(find.text('Confirmar ficha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.character!.chosenTone, isNull);
    });
  });
}
