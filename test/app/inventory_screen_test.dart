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

void main() {
  testWidgets('shows a friendly empty state when the inventory is empty', (tester) async {
    const character = Character(name: 'Damián', level: 1, exp: 0, attributes: {}, resources: {});

    await tester.pumpWidget(const MaterialApp(
      home: InventoryScreen(world: _world, character: character),
    ));

    expect(find.text('Todavía no tenés nada.'), findsOneWidget);
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

    await tester.pumpWidget(const MaterialApp(
      home: InventoryScreen(world: _world, character: character),
    ));

    expect(find.text('Revólver de servicio'), findsOneWidget);
    expect(find.text('Tres cartuchos contados, ni uno de sobra.'), findsOneWidget);
    // Undescribed id: falls back to showing the bare id, doesn't crash.
    expect(find.text('objeto_sin_describir'), findsOneWidget);
  });
}
