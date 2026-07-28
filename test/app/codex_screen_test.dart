// V2 §3b/3c/3d: CodexScreen split into "Formas de jugar" (tappable rows into
// a per-module deep dive) and "Reglas" (the general mechanics explainers
// that used to be the whole screen). No test existed for this screen before.
// V2 §1a: a third "Glosario" tab appears when world/character are supplied
// (GameScreen's status-bar icon does this) -- the per-story lore glossary.
import 'package:aetherbook/app/codex_screen.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/codex_place.dart';
import 'package:aetherbook/core/world/codex_term.dart';
import 'package:aetherbook/core/world/item_definition.dart';
import 'package:aetherbook/core/world/npc.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

World _worldWithGlossary() => World(
      slug: 'glossary_test',
      name: 'Mundo de prueba',
      theme: 'test',
      tone: 'neutro',
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: 'voluntad',
      places: const [
        CodexPlace(id: 'casa_de_tinta', displayName: 'La Casa de Tinta', description: 'Un refugio.'),
      ],
      npcs: const [
        Npc(id: 'huo_zhen', displayName: 'Huo Zhen', description: 'Un maestro retirado.'),
      ],
      items: const [
        ItemDefinition(id: 'llave', displayName: 'Llave torcida', description: 'Abre otra puerta.'),
      ],
      terms: const [
        CodexTerm(id: 'qi', displayName: 'Qi', description: 'La energía vital del mundo.'),
      ],
      startingCharacter: const Character(
        name: 'Protagonista',
        level: 1,
        exp: 0,
        attributes: {'voluntad': 1},
        resources: {},
      ),
      seedNarration: '',
      seedChoices: const [],
    );

void main() {
  Future<void> pumpCodex(WidgetTester tester) async {
    // The default 800x600 test surface is too short for this screen's
    // content (mode rows and deep-dive features sit below the fold) --
    // Sliver-based ListViews don't mount offscreen children, so `find.text`
    // can't see them without either scrolling or a tall enough viewport.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: CodexScreen()));
    await tester.pump();
  }

  testWidgets('"Formas de jugar" tab lists the 3 story modules, "Reglas" '
      'tab keeps the general mechanics sections', (tester) async {
    await pumpCodex(tester);

    expect(find.text('Historias completas'), findsOneWidget);
    expect(find.text('Historias pre-armadas'), findsOneWidget);
    expect(find.text('Crea tu propia historia'), findsOneWidget);
    expect(find.text('Las Tiradas del Destino'), findsNothing);

    await tester.tap(find.text('Reglas'));
    await tester.pumpAndSettle();

    expect(find.text('Las Tiradas del Destino'), findsOneWidget);
    expect(find.text('Todo deja huella'), findsOneWidget);
    expect(find.text('Historias completas'), findsNothing);
  });

  testWidgets('tapping a module row opens its deep-dive with features and '
      'a "qué controlas" split, and the CTA returns to the Codex',
      (tester) async {
    await pumpCodex(tester);

    await tester.tap(find.text('Historias completas'));
    await tester.pumpAndSettle();

    expect(find.text('Un protagonista con nombre propio'), findsOneWidget);
    expect(find.text('QUÉ CONTROLAS'), findsOneWidget);
    expect(find.text('Volver a las formas de jugar'), findsOneWidget);

    await tester.tap(find.text('Volver a las formas de jugar'));
    await tester.pumpAndSettle();

    expect(find.text('Un protagonista con nombre propio'), findsNothing);
    expect(find.text('Historias completas'), findsOneWidget); // back on the tab
  });

  testWidgets('each of the 3 modules opens its own distinct deep-dive',
      (tester) async {
    await pumpCodex(tester);

    await tester.tap(find.text('Historias pre-armadas'));
    await tester.pumpAndSettle();
    expect(find.text('El mundo y el conflicto ya existen'), findsOneWidget);
    await tester.tap(find.text('Volver a las formas de jugar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Crea tu propia historia'));
    await tester.pumpAndSettle();
    expect(find.text('Elegís género, no guion'), findsOneWidget);
  });

  testWidgets('without world/character, there is no "Glosario" tab',
      (tester) async {
    await pumpCodex(tester);
    expect(find.text('Glosario'), findsNothing);
  });

  testWidgets('with world/character, "Glosario" shows discovered entries in '
      'full and undiscovered ones locked, with a running count',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final world = _worldWithGlossary();
    // Only the NPC has been "discovered" (a relationship entry exists) --
    // the place, the item and the term have no such signal yet.
    const character = Character(
      name: 'Protagonista',
      level: 1,
      exp: 0,
      attributes: {'voluntad': 1},
      resources: {},
      relationships: {'huo_zhen': 1},
    );
    await tester.pumpWidget(MaterialApp(
        home: CodexScreen(world: world, character: character)));
    await tester.pump();

    await tester.tap(find.text('Glosario'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 4 entradas'), findsOneWidget);
    expect(find.text('Huo Zhen'), findsOneWidget); // discovered: full name + description
    expect(find.text('Un maestro retirado.'), findsOneWidget);
    expect(find.text('???'), findsNWidgets(3)); // lugar/objeto/término, all locked
    expect(find.text('La Casa de Tinta'), findsNothing);

    await tester.tap(find.text('Personas'));
    await tester.pumpAndSettle();
    expect(find.text('Huo Zhen'), findsOneWidget);
    expect(find.text('???'), findsNothing);
  });
}
