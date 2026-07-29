// World Builder (Admin Stage 2): a smoke test that pumps the real screen
// (not a mock) and drives it through Flutter's widget-test harness, since
// this screen has no domain logic of its own beyond binding text fields to
// World's constructor — the actual World.toJson()/fromJson() contract is
// already covered by test/world/world_json_roundtrip_test.dart.

import 'package:aetherbook/app/editor/world_builder_screen.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('blank world starts invalid; filling required fields enables Guardar', (tester) async {
    World? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await WorldBuilderScreen.open(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Constructor de mundo'), findsOneWidget);
    final saveButton = find.widgetWithText(TextButton, 'Guardar');
    expect(tester.widget<TextButton>(saveButton).onPressed, isNull);

    final slugField = _fieldAfterLabel(tester, 'Slug (único, sin espacios)');
    final nameField = _fieldAfterLabel(tester, 'Nombre');
    final attributeField = _fieldAfterLabel(tester, 'Atributo por defecto');
    final promptField = _fieldAfterLabel(tester, 'Prompt del narrador');

    await tester.enterText(slugField, 'mundo-de-prueba');
    await tester.enterText(nameField, 'Mundo de prueba');
    await tester.enterText(attributeField, 'astucia');
    await tester.enterText(promptField, 'Narra en tono noir.');
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.slug, 'mundo-de-prueba');
    expect(result!.name, 'Mundo de prueba');
    expect(result!.primaryAttribute, 'astucia');
    expect(result!.systemPrompt, 'Narra en tono noir.');
  });

  testWidgets('adding an attribute key surfaces a starting-value field for it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => WorldBuilderScreen.open(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('astucia'), findsNothing);

    final addChipButton = find.text('+ añadir').first;
    await tester.ensureVisible(addChipButton);
    await tester.pumpAndSettle();
    await tester.tap(addChipButton);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'astucia');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('astucia'), findsWidgets);
  });
}

Finder _fieldAfterLabel(WidgetTester tester, String label) {
  final labelFinder = find.text(label);
  final column = find.ancestor(of: labelFinder, matching: find.byType(Column)).first;
  return find.descendant(of: column, matching: find.byType(TextField)).first;
}
