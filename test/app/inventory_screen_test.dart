// InventoryScreen is a bottom sheet (V2 Stage 5), not a pushed screen — each
// test opens it via showInventorySheet from a throwaway Scaffold, same as a
// real caller (GameScreen) would.
import 'package:aetherbook/app/inventory_screen.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/item_definition.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _world = World(
  slug: 'curated_zombie_01_ultimo_tren',
  name: 'El último tren no espera a los vivos',
  theme: 'postapoc_zombie',
  tone: 'suspenso',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 12,
  criticalMargin: 5,
  primaryAttribute: 'instinto',
  startingCharacter: Character(name: 'Damián', level: 1, exp: 0, attributes: {}, resources: {}),
  seedNarration: '',
  seedChoices: [],
  items: [
    ItemDefinition(
      id: 'revolver_servicio',
      displayName: 'Revólver de servicio',
      description: 'Tres cartuchos contados, ni uno de sobra.',
      category: ItemCategory.weapon,
    ),
  ],
);

Future<void> _openSheet(WidgetTester tester, Character character) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showInventorySheet(context, world: _world, character: character),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a friendly empty state when the inventory is empty', (tester) async {
    const character = Character(name: 'Damián', level: 1, exp: 0, attributes: {}, resources: {});
    await _openSheet(tester, character);

    expect(find.text('Todavía no tienes nada.'), findsOneWidget);
  });

  testWidgets('shows the description for a known item and falls back to the '
      'raw id for one the world never described', (tester) async {
    const character = Character(
      name: 'Damián',
      level: 1,
      exp: 0,
      attributes: {},
      resources: {},
      lists: {
        'inventory': ['revolver_servicio', 'objeto_sin_describir'],
      },
    );
    await _openSheet(tester, character);

    expect(find.text('Revólver de servicio'), findsOneWidget);
    expect(find.text('Tres cartuchos contados, ni uno de sobra.'), findsOneWidget);
    // Undescribed id: falls back to showing the bare id, doesn't crash.
    expect(find.text('objeto_sin_describir'), findsOneWidget);
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    const character = Character(name: 'Damián', level: 1, exp: 0, attributes: {}, resources: {});
    await _openSheet(tester, character);
    expect(find.text('Inventario'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Inventario'), findsNothing);
  });
}
