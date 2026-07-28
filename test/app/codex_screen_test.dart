// V2 §3b/3c/3d: CodexScreen split into "Formas de jugar" (tappable rows into
// a per-module deep dive) and "Reglas" (the general mechanics explainers
// that used to be the whole screen). No test existed for this screen before.
import 'package:aetherbook/app/codex_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
