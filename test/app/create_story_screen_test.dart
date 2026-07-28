// No test existed for this screen before (V2 Stage 8 accessibility sweep).
// The 5-genre grid (`_GenreGridCard`, childAspectRatio: 1.15) already had a
// known, flagged-but-unfixed overflow bug at narrow physical widths (Stage
// 6h's "noted but out of scope") — this checks the other axis a fixed-ratio
// grid cell can break on: a larger OS text-scale setting, which Stage 8's
// own goal calls out ("must reflow, not clip").
import 'package:aetherbook/adapters/narrator/fake_narrator_adapter.dart';
import 'package:aetherbook/app/create_story_screen.dart';
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorldRepository implements WorldRepositoryPort {
  const _FakeWorldRepository();

  @override
  Future<World> loadWorld(String slug) async => throw UnimplementedError();
}

World _genreWorld(String slug, String name, String tone) => World(
      slug: slug,
      name: name,
      theme: slug,
      tone: tone,
      systemPrompt: '',
      imageStyleSuffix: '',
      defaultDifficulty: 12,
      criticalMargin: 5,
      primaryAttribute: 'cuerpo',
      startingCharacter: const Character(
        name: 'Protagonista',
        level: 1,
        exp: 0,
        attributes: {'cuerpo': 1},
        resources: {},
      ),
      seedNarration: '',
      seedChoices: const [],
    );

final _worlds = [
  _genreWorld('isekai', 'Isekai', 'aventura, otro mundo, segunda oportunidad'),
  _genreWorld('xianxia', 'Xianxia', 'cultivo, honor, ascenso místico'),
  _genreWorld('superheroes', 'Superhéroes', 'acción heroica, responsabilidad, sacrificio'),
  _genreWorld('cyberpunk', 'Cyberpunk', 'neón, corporaciones, resistencia urbana'),
  _genreWorld('postapoc', 'Post-apocalíptico', 'supervivencia, ruinas, comunidad'),
];

Future<void> _pump(WidgetTester tester, {double textScale = 1.0}) async {
  final controller = GameController(
    worldRepository: const _FakeWorldRepository(),
    narrator: const FakeNarratorAdapter(),
  );
  await tester.pumpWidget(
    MediaQuery(
      // `disableAnimations: true` also stops `AetherBackground`'s
      // never-ending particle drift, which otherwise makes `pumpAndSettle`
      // time out (a known gotcha documented on `AetherBackground` itself) —
      // unrelated to what this test actually checks (grid overflow).
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: true,
      ),
      child: MaterialApp(
        home: CreateStoryScreen(
          controller: controller,
          worlds: _worlds,
          onSelectGenre: (_) {},
          onResumeStory: (_) {},
          onAbandonStory: (_) async {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('renders the 5 genre cards with no overflow at the default text scale',
      (tester) async {
    await _pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Isekai'), findsOneWidget);
    expect(find.text('Post-apocalíptico'), findsOneWidget);
  });

  for (final scale in [1.3, 1.5, 2.0]) {
    testWidgets('the genre grid reflows without overflowing at textScale $scale '
        '(V2 Stage 8)', (tester) async {
      await _pump(tester, textScale: scale);
      expect(tester.takeException(), isNull);
    });
  }
}
