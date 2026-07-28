// ChargenScreen is a 3-step wizard (V2 Stage 3): step 1 (name/origin/free
// point), step 2 (tone/vow), step 3 (personal item + live preview + confirm).
// Every test below drives it exactly as a player would — filling one step,
// tapping "Siguiente", filling the next — rather than assuming every field is
// visible at once, which was true before the Stage 3 reflow but isn't anymore.
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/chargen_screen.dart';
import 'package:aetherbook/app/design/tokens.dart';
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

World _worldWith({
  List<ToneOption> tones = const [],
  bool hasFreeAttributePoint = false,
  String? themeAccentHex,
}) =>
    World(
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
      hasFreeAttributePoint: hasFreeAttributePoint,
      startingCharacter: const Character(
        name: 'Convocado', level: 1, exp: 0, attributes: {}, resources: {}),
      seedNarration: 'Comienza.',
      seedChoices: const ['Avanzar'],
      themeAccentHex: themeAccentHex,
    );

class _FakeWorldRepository implements WorldRepositoryPort {
  const _FakeWorldRepository(this.world);
  final World world;

  @override
  Future<World> loadWorld(String slug) async => world;
}

/// ChargenScreen's step content is a `SingleChildScrollView`; a tall test
/// viewport avoids needing to scroll to reach anything on a given step.
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

/// Same as [_pumpChargen] but at a given text-scale and physical width (V2
/// Stage 8) -- `disableAnimations: true` stops `AetherBackground`'s
/// never-ending particle drift so a fixed pump count settles cleanly.
Future<void> _pumpChargenAtScale(WidgetTester tester, World world,
    {required double width, required double textScale}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = GameController(
    worldRepository: _FakeWorldRepository(world),
    narrator: const FakeNarratorAdapter(latency: Duration.zero),
    dice: const FixedDice(10),
  );
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(
      size: Size(width, 1400),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    ),
    child: MaterialApp(
      home: ChargenScreen(controller: controller, worldSlug: world.slug, world: world),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Below `AetherBreakpoints.tablet` — no `_SidePanel`, so it never
/// duplicates the same `Icons.radio_button_checked`/step-checklist icons the
/// origin/vow cards themselves use, which would otherwise make a bare
/// `find.byIcon(...)` ambiguous.
Future<GameController> _pumpChargenMobile(WidgetTester tester, World world) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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

/// Fills step 1 (name + the only origin) and advances to step 2.
Future<void> _completeStepOne(WidgetTester tester, {String name = 'Yuki'}) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.tap(find.text('Convocado'));
  await tester.pump();
  await tester.tap(find.text('Siguiente'));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Fills step 2 (optional [toneLabel], the only vow) and advances to step 3.
Future<void> _completeStepTwo(WidgetTester tester, {String? toneLabel}) async {
  if (toneLabel != null) {
    await tester.tap(find.text(toneLabel));
    await tester.pump();
  }
  await tester.tap(find.text('"Voy a volver a casa."'));
  await tester.pump();
  await tester.tap(find.text('Siguiente'));
  await tester.pump(const Duration(milliseconds: 300));
}

const _tones = [
  ToneOption(id: 'epico', label: 'Épico', blurb: 'Grande, mítico', previewText: 'El umbral te reclamó.'),
  ToneOption(id: 'acido', label: 'Ácido', blurb: 'Seco, irónico', previewText: 'El destino tiene humor pésimo.'),
];

void main() {
  group('ChargenScreen — step structure (V2 Stage 3)', () {
    testWidgets('shows step 1 first, with "Siguiente" disabled until name and origin are set',
        (tester) async {
      await _pumpChargen(tester, _worldWith());

      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
      expect(find.text('Origen'), findsOneWidget);
      expect(find.text('Tono de la narración (opcional)'), findsNothing);

      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget,
          reason: 'still on step 1 — nothing filled in yet');

      await tester.enterText(find.byType(TextField).first, 'Yuki');
      await tester.tap(find.text('Convocado'));
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('a world with no free attribute point never blocks step 1 on it',
        (tester) async {
      await _pumpChargen(tester, _worldWith(hasFreeAttributePoint: false));

      expect(find.text('Punto libre (+1 a un atributo)'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'Yuki');
      await tester.tap(find.text('Convocado'));
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('a world with a free attribute point blocks step 1 until one is chosen',
        (tester) async {
      await _pumpChargen(tester, _worldWith(hasFreeAttributePoint: true));

      await tester.enterText(find.byType(TextField).first, 'Yuki');
      await tester.tap(find.text('Convocado'));
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.textContaining('Paso 1 de 3'), findsOneWidget,
          reason: 'free point not chosen yet');

      await tester.tap(find.text('ingenio'));
      await tester.pump();
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('the back arrow returns to the previous step without losing choices',
        (tester) async {
      await _pumpChargen(tester, _worldWith());
      await _completeStepOne(tester);
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Atrás'));
      await tester.pump();

      expect(find.textContaining('Paso 1 de 3'), findsOneWidget);
      // The origin choice survived going back — "Siguiente" advances in one
      // tap again instead of being blocked as if nothing had been filled.
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget);
    });

    testWidgets('step 2 blocks on the vow, then step 3 shows a live character preview',
        (tester) async {
      await _pumpChargen(tester, _worldWith());
      await _completeStepOne(tester);

      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.textContaining('Paso 2 de 3'), findsOneWidget,
          reason: 'no vow chosen yet');

      await _completeStepTwo(tester);
      await tester.pump(const Duration(milliseconds: 300)); // let the step cross-fade finish

      expect(find.textContaining('Paso 3 de 3'), findsOneWidget);
      expect(find.text('Así entras al mundo'), findsOneWidget);
      expect(find.text('Yuki'), findsOneWidget);
      expect(find.textContaining('Voy a volver a casa'), findsOneWidget);
    });
  });

  group('ChargenScreen tone step (V2 Stage 6c)', () {
    testWidgets('is not shown at all for a world with no tones', (tester) async {
      await _pumpChargen(tester, _worldWith());
      await _completeStepOne(tester);

      expect(find.text('Tono de la narración (opcional)'), findsNothing);
    });

    testWidgets('shows every declared tone; tapping one reveals its preview',
        (tester) async {
      await _pumpChargen(tester, _worldWith(tones: _tones));
      await _completeStepOne(tester);

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
      await _completeStepOne(tester);

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
      await _completeStepOne(tester);
      await _completeStepTwo(tester, toneLabel: 'Ácido');

      await tester.tap(find.text('Confirmar ficha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.character!.chosenTone, 'acido');
    });

    testWidgets('confirming without picking a tone leaves it null', (tester) async {
      final controller = await _pumpChargen(tester, _worldWith(tones: _tones));
      await _completeStepOne(tester);
      await _completeStepTwo(tester);

      await tester.tap(find.text('Confirmar ficha'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(controller.character!.chosenTone, isNull);
    });
  });

  group('ChargenScreen responsive layout (V2 §1c pattern)', () {
    testWidgets('mobile (< 700px): no step checklist side panel', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final controller = GameController(
        worldRepository: _FakeWorldRepository(_worldWith()),
        narrator: const FakeNarratorAdapter(latency: Duration.zero),
        dice: const FixedDice(10),
      );
      await tester.pumpWidget(MaterialApp(
        home: ChargenScreen(controller: controller, worldSlug: 'isekai', world: _worldWith()),
      ));
      await tester.pump();

      // World name appears once (the step-1 heading) -- no side panel yet.
      expect(find.text('Isekai'), findsOneWidget);
    });

    testWidgets(
        'wide (>= 700px): a side panel shows the world name and step '
        'checklist, and the live preview appears there instead of being '
        'duplicated inside step 3', (tester) async {
      await _pumpChargen(tester, _worldWith()); // 900px-wide tall viewport
      await _completeStepOne(tester);
      await _completeStepTwo(tester);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Paso 3 de 3 · Últimos detalles'), findsOneWidget);
      // World name: once in the side panel, once as the step-1 heading is
      // gone by now (step 3 doesn't repeat it) -- so exactly one match.
      expect(find.text('Isekai'), findsOneWidget);
      // The live preview shows exactly once (in the side panel), not
      // duplicated inside step 3's own content.
      expect(find.text('Así entras al mundo'), findsOneWidget);
    });
  });

  group('ChargenScreen text-scale accessibility (V2 Stage 8)', () {
    for (final width in [400.0, 1000.0]) {
      for (final scale in [1.3, 1.5, 2.0]) {
        testWidgets(
            'reflows without overflowing at width $width, textScale $scale',
            (tester) async {
          await _pumpChargenAtScale(tester, _worldWith(), width: width, textScale: scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('ChargenScreen per-world theming (V2 §4a-4d)', () {
    testWidgets('an unthemed world keeps everything gold, same as before', (tester) async {
      await _pumpChargenMobile(tester, _worldWith());

      await tester.tap(find.text('Convocado'));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.radio_button_checked));
      expect(icon.color, AetherColors.gold);
    });

    testWidgets('a themed world tints the selected origin card with its own accent, not gold',
        (tester) async {
      await _pumpChargenMobile(tester, _worldWith(themeAccentHex: '#F0564A'));

      await tester.tap(find.text('Convocado'));
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.radio_button_checked));
      expect(icon.color, const Color(0xFFF0564A));
      expect(icon.color, isNot(AetherColors.gold));
    });

    testWidgets('a themed world tints the selected free-attribute-point chip', (tester) async {
      await _pumpChargenMobile(
          tester, _worldWith(hasFreeAttributePoint: true, themeAccentHex: '#F0564A'));

      await tester.tap(find.text('ingenio'));
      await tester.pump();

      final chipText = tester.widget<Text>(find.text('ingenio'));
      expect(chipText.style?.color, const Color(0xFFF0564A));
    });

    testWidgets('a themed world tints the step CTA button, not the fixed gold gradient',
        (tester) async {
      await _pumpChargenMobile(tester, _worldWith(themeAccentHex: '#F0564A'));
      await tester.enterText(find.byType(TextField).first, 'Yuki');
      await tester.tap(find.text('Convocado'));
      await tester.pump();

      final container = tester
          .widget<Container>(find.ancestor(of: find.text('Siguiente'), matching: find.byType(Container)).first);
      final gradient = (container.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors.first, const Color(0xFFF0564A));
    });

    testWidgets('a themed world tints the live character-preview box border and vow quote',
        (tester) async {
      await _pumpChargenMobile(tester, _worldWith(themeAccentHex: '#F0564A'));
      await _completeStepOne(tester);
      await _completeStepTwo(tester);
      await tester.pump(const Duration(milliseconds: 300));

      final vowQuote = tester.widget<Text>(find.textContaining('Voy a volver a casa'));
      expect(vowQuote.style?.color, const Color(0xFFF0564A));
    });
  });
}
