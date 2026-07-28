// Covers GameController.availableEndings/chooseEnding — the climax
// mechanism (ResolutionNode.endings, Ending.difficultyFor, failure
// fallbacks, final technique granting, and advancing into a pure epilogue
// node's assembled beats) that xianxia_lianshu's existing coverage never
// exercised, since the vertical slice stops well before the ritual.
// An AI-free synthetic world (same pattern as
// game_controller_curated_no_ai_test.dart) so the produced narration is
// exactly `Ending.successReveals`/`costReveals` — no narrator output to
// account for.
import 'package:aetherbook/app/game_controller.dart';
import 'package:aetherbook/core/engine/dice.dart';
import 'package:aetherbook/core/narrative/ending.dart';
import 'package:aetherbook/core/narrative/ending_fallback.dart';
import 'package:aetherbook/core/narrative/epilogue_beat.dart';
import 'package:aetherbook/core/narrative/final_technique_rule.dart';
import 'package:aetherbook/core/narrative/gate.dart';
import 'package:aetherbook/core/narrative/story_graph.dart';
import 'package:aetherbook/core/narrative/story_node.dart';
import 'package:aetherbook/core/narrative/extended_conflict.dart';
import 'package:aetherbook/core/state/character.dart';
import 'package:aetherbook/core/state/game_session.dart';
import 'package:aetherbook/ports/game_state_repository_port.dart';
import 'package:aetherbook/ports/narrator_port.dart';
import 'package:aetherbook/ports/world_repository_port.dart';
import 'package:aetherbook/core/world/world.dart';
import 'package:flutter_test/flutter_test.dart';

class _ForbiddenNarrator implements NarratorPort {
  const _ForbiddenNarrator();

  @override
  Future<NarratorResponse> narrate(NarratorRequest request) async {
    fail('NarratorPort.narrate must never be called for an AI-free world');
  }
}

final _graph = StoryGraph(
  startNodeId: 'climax',
  nodes: {
    'climax': const ResolutionNode(
      id: 'climax',
      narration: 'El momento de decidir llegó.',
      epilogueNodeId: 'epilogo',
      finalTechniqueRules: [
        FinalTechniqueRule(gate: AlwaysGate(), techniqueId: 'tecnica_comun'),
      ],
      endings: [
        Ending(
          id: 'final_luz',
          visibleChoice: 'Elegir la luz',
          baseDifficulty: 10,
          successReveals: ['La luz gana.'],
          costReveals: ['Algo se apaga.'],
        ),
        Ending(
          id: 'final_oscuro',
          visibleChoice: 'Elegir la oscuridad',
          baseDifficulty: 10,
          successReveals: ['La oscuridad gana.'],
          costReveals: ['El costo es alto.'],
          failureCostOptions: ['pierde su nombre'],
          onFailureFallbacks: [
            EndingFallback(gate: AlwaysGate(), endingId: 'final_oscuro_fracturado'),
          ],
        ),
        Ending(
          id: 'final_secreto',
          visibleChoice: 'El final oculto',
          hardRequirement: FlagGate('saw_truth'),
        ),
      ],
    ),
    'epilogo': const ResolutionNode(
      id: 'epilogo',
      epilogueBeats: [
        EpilogueBeat(
          movement: 'cierre',
          gate: FlagGate('ending_final_luz'),
          text: 'Todo termina en luz.',
        ),
        EpilogueBeat(
          movement: 'cierre',
          gate: FlagGate('ending_final_oscuro_fracturado'),
          text: 'Todo termina fracturado.',
        ),
        EpilogueBeat(
          movement: 'cierre',
          gate: AlwaysGate(),
          text: 'El final llega de todos modos.',
        ),
      ],
    ),
  },
);

final _world = World(
  slug: 'climax_test',
  name: 'Mundo de prueba del clímax',
  theme: 'test',
  tone: 'neutro',
  systemPrompt: '',
  imageStyleSuffix: '',
  defaultDifficulty: 99, // deliberately absurd -- endings never use this
  criticalMargin: 5,
  primaryAttribute: 'voluntad',
  storyGraph: _graph,
  startingCharacter: const Character(
    name: 'Protagonista',
    level: 1,
    exp: 0,
    attributes: {'voluntad': 1},
    resources: {},
    vowId: 'no_dejar_a_nadie',
  ),
  seedNarration: '',
  seedChoices: const [],
  aiRuntimeRequired: false,
  allowFreeText: false,
);

class _FakeWorldRepository implements WorldRepositoryPort {
  _FakeWorldRepository([World? overrideWorld]) : _servedWorld = overrideWorld ?? _world;

  final World _servedWorld;

  @override
  Future<World> loadWorld(String slug) async => _servedWorld;
}

GameController _controllerWith(Dice dice) => GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const _ForbiddenNarrator(),
      dice: dice,
    );

/// Minimal in-memory [GameStateRepositoryPort] — only `createSession` and
/// `completeSession` matter for the vow-finalization/session-completion
/// tests below, everything else is a no-op.
class _FakeGameStateRepository implements GameStateRepositoryPort {
  final List<String> completedSessionIds = [];

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
    String? title,
  }) async =>
      GameSession(id: 'session-climax', worldSlug: worldSlug, character: character);

  @override
  Future<void> completeSession(String sessionId) async {
    completedSessionIds.add(sessionId);
  }

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async => null;

  @override
  Future<GameSession?> loadSession(String sessionId) async => null;

  @override
  Future<List<GameSessionSummary>> listActiveSessions(List<String> worldSlugs) async => const [];

  @override
  Future<void> saveCharacter(String sessionId, Character character) async {}

  @override
  Future<void> appendTurn({
    required String sessionId,
    required int turnIndex,
    required playerAction,
    required resolution,
    required String narration,
    required String tone,
    required List<String> suggestedChoices,
  }) async {}

  @override
  Future<void> saveTurnImage({
    required String sessionId,
    required int turnIndex,
    required String imageUrl,
  }) async {}

  @override
  Future<void> saveGraphPosition({
    required String sessionId,
    String? currentNodeId,
    required int corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
  }) async {}

  @override
  Future<void> abandonSession(String sessionId) async {}

  @override
  Future<List<SessionReadingStat>> readingStats() async => const [];

  @override
  Future<String?> loadLatestMemoryDigest(String sessionId) async => null;

  @override
  Future<void> saveMemoryDigest({
    required String sessionId,
    required int upToTurn,
    required String summaryText,
  }) async {}
}

GameController _controllerWithPersistence(Dice dice, _FakeGameStateRepository persistence) =>
    GameController(
      worldRepository: _FakeWorldRepository(),
      narrator: const _ForbiddenNarrator(),
      persistence: persistence,
      dice: dice,
    );

void main() {
  group('GameController.availableEndings', () {
    test('filters out an ending whose hard requirement is not met', () async {
      final controller = _controllerWith(const FixedDice(10));
      await controller.start('climax_test');

      final ids = controller.availableEndings.map((e) => e.id).toSet();
      expect(ids, {'final_luz', 'final_oscuro'});
      expect(ids.contains('final_secreto'), isFalse);
    });
  });

  group('GameController achievedEndingOrdinal/achievedEndingsTotal '
      '(V2 "Final descubierto · N de M")', () {
    test('are null before any ending has been chosen', () async {
      final controller = _controllerWith(const FixedDice(10));
      await controller.start('climax_test');

      expect(controller.achievedEndingOrdinal, isNull);
      expect(controller.achievedEndingsTotal, isNull);
    });

    test('reset to null when start() begins a new session', () async {
      final controller = _controllerWith(const FixedDice(20));
      await controller.start('climax_test');
      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_luz');
      await controller.chooseEnding(ending);
      expect(controller.achievedEndingOrdinal, isNotNull);

      await controller.start('climax_test', forceNew: true);

      expect(controller.achievedEndingOrdinal, isNull);
      expect(controller.achievedEndingsTotal, isNull);
    });
  });

  group('GameController.chooseEnding — success', () {
    test('sets the ending flag, grants the technique, and advances into the '
        "epilogue's matching beat", () async {
      final controller = _controllerWith(const FixedDice(20)); // natural 20 -> always succeeds
      await controller.start('climax_test');

      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_luz');
      await controller.chooseEnding(ending);

      expect(controller.error, isNull);
      expect(controller.character!.flag('ending_final_luz'), isTrue);
      expect(controller.character!.varValue('final_technique_id'), 'tecnica_comun');
      expect(controller.narration, contains('La luz gana.'));
      expect(controller.narration, contains('Algo se apaga.'));

      expect(controller.currentNode!.id, 'epilogo');
      expect(controller.availableStoryChoices, isEmpty);
      expect(controller.availableEndings, isEmpty);
      expect(controller.narration, contains('Todo termina en luz.'));
      // The unrelated fallback-only beat must not also show.
      expect(controller.narration, isNot(contains('fracturado')));

      // 'final_luz' is authored first among 'climax's 3 declared endings —
      // still true here even though 'currentNode' has already moved on to
      // the epilogue and 'availableEndings' is empty again.
      expect(controller.achievedEndingOrdinal, 1);
      expect(controller.achievedEndingsTotal, 3);
    });
  });

  group('GameController.chooseEnding — failure with a fallback', () {
    test('redirects to the fallback ending id instead of undoing the scene',
        () async {
      final controller = _controllerWith(const FixedDice(1)); // natural 1 -> always fails
      await controller.start('climax_test');

      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_oscuro');
      await controller.chooseEnding(ending);

      expect(controller.error, isNull);
      // The attempted ending's own flag is NOT what gets set on failure --
      // the fallback's id is.
      expect(controller.character!.flag('ending_final_oscuro'), isFalse);
      expect(controller.character!.flag('ending_final_oscuro_fracturado'), isTrue);
      // A failed check still costs -- it doesn't reset the game or skip the
      // scene, same rule as every other check in the engine.
      expect(controller.narration, contains('El costo es alto.'));
      expect(controller.narration, contains('pierde su nombre'));

      expect(controller.currentNode!.id, 'epilogo');
      expect(controller.narration, contains('Todo termina fracturado.'));

      // The ordinal reflects the ending the player attempted ('final_oscuro',
      // authored 2nd), not the fallback id the failure redirected to.
      expect(controller.achievedEndingOrdinal, 2);
      expect(controller.achievedEndingsTotal, 3);
    });
  });

  group('GameController.chooseEnding — vow finalization & session completion '
      '(V2 §6a Perfil)', () {
    test('a vow never tested becomes sostenido, and the session is marked completed',
        () async {
      final persistence = _FakeGameStateRepository();
      final controller = _controllerWithPersistence(const FixedDice(20), persistence);
      await controller.start('climax_test');

      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_luz');
      await controller.chooseEnding(ending);

      expect(controller.character!.varValue('vow_status'), 'sostenido');
      expect(persistence.completedSessionIds, ['session-climax']);
    });

    test('a vow already broken earlier in the story is never overwritten back to sostenido',
        () async {
      // A variant of the same climax world whose starting character already
      // carries `vow_status: roto` — standing in for "the narrator proposed
      // `roto` on an earlier turn" without needing a mid-story delta
      // injection path this AI-free synthetic world has no way to exercise.
      final brokenVowWorld = World(
        slug: 'climax_test',
        name: 'Mundo de prueba del clímax',
        theme: 'test',
        tone: 'neutro',
        systemPrompt: '',
        imageStyleSuffix: '',
        defaultDifficulty: 99,
        criticalMargin: 5,
        primaryAttribute: 'voluntad',
        storyGraph: _graph,
        startingCharacter: const Character(
          name: 'Protagonista',
          level: 1,
          exp: 0,
          attributes: {'voluntad': 1},
          resources: {},
          vowId: 'no_dejar_a_nadie',
          vars: {'vow_status': 'roto'},
        ),
        seedNarration: '',
        seedChoices: const [],
        aiRuntimeRequired: false,
        allowFreeText: false,
      );
      final persistence = _FakeGameStateRepository();
      final controller = GameController(
        worldRepository: _FakeWorldRepository(brokenVowWorld),
        narrator: const _ForbiddenNarrator(),
        persistence: persistence,
        dice: const FixedDice(20),
      );
      await controller.start('climax_test');

      final ending =
          controller.availableEndings.firstWhere((e) => e.id == 'final_luz');
      await controller.chooseEnding(ending);

      expect(controller.character!.varValue('vow_status'), 'roto');
      expect(persistence.completedSessionIds, ['session-climax']);
    });
  });
}
