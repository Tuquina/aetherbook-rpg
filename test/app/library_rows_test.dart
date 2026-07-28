import 'package:aetherbook/app/library_rows.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  World freeformWorld({bool aiRuntimeRequired = true}) => World(
        slug: 'isekai',
        name: 'Isekai',
        theme: 'isekai',
        tone: 'neutro',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 12,
        criticalMargin: 5,
        primaryAttribute: 'cuerpo',
        startingCharacter: const Character(
            name: 'Protagonista', level: 1, exp: 0, attributes: {}, resources: {}),
        seedNarration: '',
        seedChoices: const [],
        aiRuntimeRequired: aiRuntimeRequired,
      );

  World curatedWorldWithChapters(int totalChapters) => World.fromJson({
        'slug': 'curated_zombie',
        'name': 'El último tren no espera a los vivos',
        'starting_character': {'name': 'Protagonista', 'level': 1, 'exp': 0},
        'ai_runtime_required': false,
        'graph': {
          'start_node': 'p_prologo',
          'nodes': {
            'p_prologo': {'narration': '...'},
            for (var i = 1; i <= totalChapters; i++)
              'c${i}_n01': {'narration': '...'},
          },
        },
      });

  SessionLibraryEntry entry({
    String status = 'active',
    int turnCount = 0,
    String? currentNodeId,
  }) =>
      SessionLibraryEntry(
        sessionId: 's1',
        worldSlug: 'test',
        status: status,
        characterName: 'Fernando',
        turnCount: turnCount,
        updatedAt: DateTime.now(),
        currentNodeId: currentNodeId,
      );

  group('LibraryRow.progress', () {
    test('is null for an unstarted row (no session)', () {
      final row = LibraryRow(world: freeformWorld());
      expect(row.progress, isNull);
    });

    test('is always full for a completed session, regardless of world type', () {
      final row = LibraryRow(world: freeformWorld(), entry: entry(status: 'completed'));
      expect(row.progress, 1.0);
    });

    test('a curated, AI-free world with a graph position gets real chapter progress', () {
      final world = curatedWorldWithChapters(10);
      final row = LibraryRow(world: world, entry: entry(currentNodeId: 'c4_n01'));
      expect(row.progress, closeTo(4 / 10, 0.001));
    });

    test('an AI-narrated (freeform) world always uses the turnCount heuristic, '
        'even with a currentNodeId', () {
      final row =
          LibraryRow(world: freeformWorld(), entry: entry(turnCount: 9, currentNodeId: 'c4_n01'));
      expect(row.progress, closeTo(9 / 30, 0.001));
    });

    test('a curated world with no currentNodeId yet falls back to the heuristic', () {
      final world = curatedWorldWithChapters(10);
      final row = LibraryRow(world: world, entry: entry(turnCount: 3));
      expect(row.progress, closeTo(3 / 30, 0.001));
    });

    test('the turnCount heuristic clamps at 1.0 past its ceiling', () {
      final row = LibraryRow(world: freeformWorld(), entry: entry(turnCount: 90));
      expect(row.progress, 1.0);
    });

    test('chapter progress clamps at 1.0 if somehow past the last known chapter', () {
      final world = curatedWorldWithChapters(5);
      final row = LibraryRow(world: world, entry: entry(currentNodeId: 'c9_n01'));
      expect(row.progress, 1.0);
    });
  });
}
