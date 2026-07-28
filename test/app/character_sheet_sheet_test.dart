import 'package:aetherbook/app/character_sheet_sheet.dart';
import 'package:aetherbook/app/design/tokens.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> baseWorldJson() => {
        'slug': 'test',
        'name': 'Mundo de prueba',
        'attributes': ['cuerpo'],
        'starting_character': {
          'name': 'Protagonista',
          'level': 1,
          'exp': 0,
          'attributes': {'cuerpo': 4},
        },
      };

  Future<void> openSheet(
    WidgetTester tester,
    World world, {
    int turnCount = 1,
    Character? character,
  }) async {
    // `personal_item` isn't world-declarative JSON (§7 of CLAUDE.md) — it's
    // set during chargen, so it's added here via copyWith instead.
    final resolvedCharacter =
        character ?? world.startingCharacter.copyWith(personalItem: 'Un amuleto roto');
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showCharacterSheet(
              context, world: world, character: resolvedCharacter, turnCount: turnCount),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a themed world tints the attribute bar and the info chip with its accent',
      (tester) async {
    final world = World.fromJson(baseWorldJson()..['theme_accent'] = '#7FD4C1');
    await openSheet(tester, world);

    final fsb = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    final fill = fsb.child as Container;
    expect(fill.color, const Color(0xFF7FD4C1));
    expect(fsb.widthFactor, closeTo(4 / 5, 0.001)); // decorative cap of 5

    final icon = tester.widget<Icon>(find.byIcon(Icons.auto_stories_rounded));
    expect(icon.color, const Color(0xFF7FD4C1));
  });

  testWidgets('a themeless world falls back to the global gold accent', (tester) async {
    final world = World.fromJson(baseWorldJson());
    await openSheet(tester, world);

    final fsb = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox));
    final fill = fsb.child as Container;
    expect(fill.color, AetherColors.gold);

    final icon = tester.widget<Icon>(find.byIcon(Icons.auto_stories_rounded));
    expect(icon.color, AetherColors.gold);
  });

  testWidgets('shows a subtitle with the world name, module and turn count', (tester) async {
    // No `graph` declared -> moduleFor resolves this to "Crea tu propia historia".
    final world = World.fromJson(baseWorldJson());
    await openSheet(tester, world, turnCount: 12);

    expect(find.text('Mundo de prueba · Crea tu propia historia · turno 12'), findsOneWidget);
  });

  group('flag-derived narrative tags (V2 §4c)', () {
    testWidgets('shows a tag when its flag is set, tinted with theme.secondary',
        (tester) async {
      final world = World.fromJson(baseWorldJson()
        ..['theme_secondary'] = '#FF4FA3'
        ..['character_tags'] = [
          {'flag': 'deuda_impaga', 'label': 'Marca: deuda impaga'},
        ]);
      final character = world.startingCharacter.copyWith(flags: {'deuda_impaga': true});
      await openSheet(tester, world, character: character);

      expect(find.text('Marca: deuda impaga'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.local_offer_outlined));
      expect(icon.color, const Color(0xFFFF4FA3));
    });

    testWidgets('hides the tag when its flag is false or unset', (tester) async {
      final world = World.fromJson(baseWorldJson()
        ..['character_tags'] = [
          {'flag': 'deuda_impaga', 'label': 'Marca: deuda impaga'},
        ]);
      await openSheet(tester, world); // startingCharacter has no flags set

      expect(find.text('Marca: deuda impaga'), findsNothing);
    });
  });

  group('avatar (V2 §4c)', () {
    testWidgets('renders the generated portrait when avatarUrl is set', (tester) async {
      final world = World.fromJson(baseWorldJson());
      final character = world.startingCharacter
          .copyWith(avatarUrl: 'https://cdn.aetherbook.dev/scene-images/avatar1.png');
      await openSheet(tester, world, character: character);

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('falls back to an accent-tinted initial when avatarUrl is null',
        (tester) async {
      final world = World.fromJson(baseWorldJson()..['theme_accent'] = '#7FD4C1');
      // startingCharacter's name is "Protagonista" -> initial "P".
      await openSheet(tester, world);

      expect(find.byType(Image), findsNothing);
      expect(find.text('P'), findsOneWidget);
    });
  });
}
