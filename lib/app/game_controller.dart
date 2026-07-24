// prefer_initializing_formals is disabled here: the fields are private and
// Dart forbids private *named* parameters, so `this._field` initializing
// formals are not usable for this public named-argument constructor.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../core/engine/action_resolution.dart';
import '../core/engine/apply_state_deltas.dart';
import '../core/engine/create_character.dart';
import '../core/engine/dice.dart';
import '../core/engine/exp_progression.dart';
import '../core/engine/infer_action_attribute.dart';
import '../core/engine/interpolate_copy.dart';
import '../core/engine/rank_progression.dart';
import '../core/engine/resolve_player_action.dart';
import '../core/engine/resolve_story_choice.dart';
import '../core/engine/state_delta.dart';
import '../core/narrative/checkable.dart';
import '../core/narrative/extended_conflict.dart';
import '../core/narrative/hub_activity.dart';
import '../core/narrative/story_choice.dart';
import '../core/narrative/story_node.dart';
import '../core/state/character.dart';
import '../core/state/game_session.dart';
import '../core/world/world.dart';
import '../ports/game_state_repository_port.dart';
import '../ports/memory_digest_port.dart';
import '../ports/narrator_port.dart';
import '../ports/world_repository_port.dart';

/// The current node's fixed_reveals/forbidden_reveals/goal, extracted once
/// per turn so both the freeform and the curated turn paths can pass the
/// same context into the narrator (campaign-bible §18: the AI must respect
/// what a curated node fixes/forbids, and stay inside a corridor's goal).
typedef _NodeContext = ({
  List<String> fixedReveals,
  List<String> forbiddenReveals,
  String? goal,
});

/// Drives the core gameplay loop (GDD §3), wiring the ports together:
///
///   choose -> resolve mechanics (engine) -> narrate (port) ->
///   validate & apply deltas (engine) -> update state -> notify UI
///
/// It depends only on ports and pure engine use cases, never on a concrete AI
/// provider. The randomness source is injectable so the loop is testable.
///
/// Fase 0-6 only ever played a freeform world (`world.storyGraph == null`):
/// every turn inferred an attribute by keyword and rolled against
/// `world.defaultDifficulty`. Fase 8 adds the hybrid/curated path for a world
/// that declares a `StoryGraph` (campaign-bible format): [currentNode],
/// [availableStoryChoices] and [availableActivities] expose what the graph
/// offers right now, and [chooseStoryChoice]/[chooseHubActivity] resolve a
/// tapped option with *its own* attribute/difficulty (never the world
/// default) via `ResolveStoryChoice`. [choose] (free text) keeps working
/// exactly as before in both modes, with one addition: inside a
/// `BoundedCorridorNode`, it also counts down that corridor's turn budget.
///
/// [persistence] is optional: when `null` (Fase 0 default), state lives only
/// in memory for the life of the app, exactly as before. When provided
/// (Fase 1), each turn is also durably recorded in Postgres and a session is
/// resumed on [start] instead of always beginning from the world's seed.
/// Persisting `currentNodeId`/corridor turn counters is not implemented yet
/// (Fase 8 plays the vertical slice in memory) — a resumed session for a
/// curated world simply restarts at the graph's `startNodeId`.
///
/// [memoryDigest] is also optional: when configured, every [digestEveryNTurns]
/// the last turns are compressed into a medium-term summary (CLAUDE.md §6,
/// GDD §5.3) that then travels in every subsequent narrator prompt, instead of
/// the model ever seeing the full turn history.
class GameController extends ChangeNotifier {
  GameController({
    required WorldRepositoryPort worldRepository,
    required NarratorPort narrator,
    GameStateRepositoryPort? persistence,
    MemoryDigestPort? memoryDigest,
    int digestEveryNTurns = 5,
    Dice? dice,
  })  : _worldRepository = worldRepository,
        _narrator = narrator,
        _persistence = persistence,
        _memoryDigest = memoryDigest,
        _digestEveryNTurns = digestEveryNTurns,
        _resolve = ResolvePlayerAction(dice ?? RandomDice()),
        _inferAttribute = const InferActionAttribute(),
        _interpolate = const InterpolateCopy() {
    _resolveStoryChoice = ResolveStoryChoice(_resolve);
  }

  final WorldRepositoryPort _worldRepository;
  final NarratorPort _narrator;
  final GameStateRepositoryPort? _persistence;
  final MemoryDigestPort? _memoryDigest;
  final int _digestEveryNTurns;
  final ResolvePlayerAction _resolve;
  final InferActionAttribute _inferAttribute;
  final InterpolateCopy _interpolate;
  late final ResolveStoryChoice _resolveStoryChoice;

  /// Rebuilt per-world in [start] so EXP thresholds match the world's own
  /// progression config (a world may scale levels differently, or not at all).
  ApplyStateDeltas _applyDeltas = const ApplyStateDeltas();
  String? _memoryDigestText;

  World? _world;
  GameSession? _session;
  List<String> _choices = const [];
  String _narration = '';
  String _tone = '';
  ActionResolution? _lastResolution;
  int _lastLevelsGained = 0;
  bool _isLoading = false;
  String? _error;

  World? get world => _world;
  Character? get character => _session?.character;
  List<String> get choices => _choices;
  String get narration => _narration;
  String get tone => _tone;
  ActionResolution? get lastResolution => _lastResolution;
  int get lastLevelsGained => _lastLevelsGained;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isReady => _world != null && _session != null;

  /// The current medium-term memory digest, if any has been generated yet.
  String? get memoryDigestText => _memoryDigestText;

  /// Where the player currently is in the world's `StoryGraph`, or `null` for
  /// a freeform world with no graph at all (Fase 0 style).
  StoryNode? get currentNode {
    final graph = _world?.storyGraph;
    final nodeId = _session?.currentNodeId;
    if (graph == null || nodeId == null) return null;
    return graph.nodeById(nodeId);
  }

  /// The curated choices/exits available right now, already filtered by
  /// gate — empty outside a curated node (or with no character yet).
  List<StoryChoice> get availableStoryChoices {
    final node = currentNode;
    final character = this.character;
    if (node == null || character == null) return const [];
    return switch (node) {
      FixedAnchorNode n => n.availableChoices(character),
      BoundedCorridorNode n => n.availableChoices(character),
      StateHubNode n => n.availableExits(character),
      ResolutionNode() => const [],
    };
  }

  /// The current node's hub activities, already filtered by gate — empty
  /// unless [currentNode] is a `StateHubNode`.
  List<HubActivity> get availableActivities {
    final node = currentNode;
    final character = this.character;
    if (node is! StateHubNode || character == null) return const [];
    return node.availableActivities(character);
  }

  /// Loads a world's declarative data without starting a session — used by
  /// `SplashScreen`/`ChargenScreen` to decide whether a world needs
  /// structured chargen (campaign-bible §5) before the player can actually
  /// start playing, without duplicating the world-selection logic here.
  Future<World> loadWorldInfo(String worldSlug) => _worldRepository.loadWorld(worldSlug);

  /// Loads a world and sets up the opening scene — resumed from a persisted
  /// session if [persistence] is configured and one already exists, or from
  /// the world's seed/graph start otherwise. [chargenInput] is required to
  /// build the starting character for a world that declares chargen origins
  /// (campaign-bible §5) — ignored for a world that doesn't (Fase 0 style,
  /// which keeps using `world.startingCharacter`).
  /// [forceNew] abandons whatever session was already in progress for
  /// [worldSlug] (if persisted) and always starts a clean one instead of
  /// resuming — the "reiniciar historia" affordance on [WorldSelectScreen],
  /// for a player who wants to play a curated campaign again from the top
  /// rather than pick up where they left off.
  Future<void> start(
    String worldSlug, {
    CreateCharacterInput? chargenInput,
    bool forceNew = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final world = await _worldRepository.loadWorld(worldSlug);
      _world = world;
      _applyDeltas = ApplyStateDeltas(
        progression:
            ExpProgression(baseExpPerLevel: world.progression.baseExpPerLevel),
        meterDefinitions: world.meterDefinitions,
        rankProgression:
            world.ranks.isEmpty ? null : RankProgression(world.ranks),
        resourceFormulas: world.resourceFormulas,
        relationshipMagnitudeCap: world.relationshipMagnitudeCap,
        relationshipMin: world.relationshipMin,
        relationshipMax: world.relationshipMax,
      );

      final persistence = _persistence;
      GameSession session;
      if (persistence != null) {
        var existing = await persistence.loadLatestSession(worldSlug);
        if (forceNew && existing != null) {
          final staleId = existing.id;
          if (staleId != null) await persistence.abandonSession(staleId);
          existing = null;
        }
        session = existing ??
            await persistence.createSession(
              worldSlug: world.slug,
              character: _initialCharacter(world, chargenInput),
            );
      } else {
        session = GameSession(
          worldSlug: world.slug,
          character: _initialCharacter(world, chargenInput),
        );
      }

      final graph = world.storyGraph;
      if (graph != null && session.currentNodeId == null) {
        session = session.copyWith(currentNodeId: graph.startNodeId);
      }
      _session = session;

      _memoryDigestText = null;
      if (persistence != null && session.id != null) {
        _memoryDigestText = await persistence.loadLatestMemoryDigest(session.id!);
      }

      if (session.turns.isNotEmpty) {
        final lastTurn = session.turns.last;
        _narration = lastTurn.narration;
        _choices = lastTurn.suggestedChoices;
        _tone = lastTurn.tone.isNotEmpty ? lastTurn.tone : world.tone;
      } else if (graph != null) {
        final node = graph.nodeById(session.currentNodeId!);
        _narration = _literalNarrationOf(node, session.character) ?? world.seedNarration;
        _choices = const [];
        _tone = world.tone;
      } else {
        _narration = world.seedNarration;
        _choices = world.seedChoices;
        _tone = world.tone;
      }
      _lastResolution = null;
      _lastLevelsGained = 0;
    } catch (e) {
      _error = 'No se pudo cargar el mundo: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Character _initialCharacter(World world, CreateCharacterInput? chargenInput) {
    if (chargenInput != null) {
      return const CreateCharacter()(world, chargenInput);
    }
    return world.startingCharacter;
  }

  /// The node's own pre-written opening prose, if it has one — only a
  /// `FixedAnchorNode` carries literal narration (campaign-bible's curated
  /// hitos); corridors/hubs/resolutions have none and rely on the narrator.
  /// Appends every `conditionalInserts` block whose gate [character]
  /// satisfies, and interpolates `{{token}}` placeholders against it.
  String? _literalNarrationOf(StoryNode node, Character character) {
    if (node is! FixedAnchorNode) return null;
    final inserts = node.satisfiedInserts(character);
    if (node.narration.isEmpty && inserts.isEmpty) return null;
    final blocks = [
      if (node.narration.isNotEmpty) node.narration,
      ...inserts,
    ];
    return _interpolate(
      blocks.join('\n\n'),
      character: character,
      protagonistName: character.name,
    );
  }

  _NodeContext _nodeContext(StoryNode? node) {
    return switch (node) {
      FixedAnchorNode n => (
          fixedReveals: n.fixedReveals,
          forbiddenReveals: n.forbiddenReveals,
          goal: null,
        ),
      BoundedCorridorNode n => (
          fixedReveals: const <String>[],
          forbiddenReveals: n.forbiddenReveals,
          goal: n.goal,
        ),
      _ => (fixedReveals: const <String>[], forbiddenReveals: const <String>[], goal: null),
    };
  }

  /// Plays one turn for the free-typed [action] — works in both freeform and
  /// curated worlds. Inside a `BoundedCorridorNode`, a free action also
  /// spends one of the corridor's turn budget; once exhausted, the scene is
  /// forced to the corridor's `fallbackExitNodeId` after this turn narrates
  /// (campaign-bible §18.8).
  Future<void> choose(String action) async {
    final world = _world;
    final session = _session;
    if (world == null || session == null || _isLoading) return;
    // A curated, AI-free campaign (`allowFreeText == false`) never offers
    // this field in the UI — this guard just makes that unreachable instead
    // of relying solely on the UI to enforce it (campaign-bible §25.10).
    if (!world.allowFreeText) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    // Resolve mechanics deterministically — the engine decides, not the AI.
    // Which attribute a check uses is also decided in code, via keyword
    // matching declared per world (CLAUDE.md §2.2, GDD §4.1) — the AI never
    // picks the attribute, whether the action was typed freely or tapped
    // from a suggested choice. `ClassifyFreeAction` (Fase 6) isn't wired in
    // here yet — deliberately deferred past the Fase 8 vertical slice.
    final attributeKey = _inferAttribute(
      action: action,
      attributeKeywords: world.attributeKeywords,
      fallback: world.primaryAttribute,
    );
    final resolution = _resolve(
      attributeKey: attributeKey,
      attribute: session.character.attribute(attributeKey),
      difficulty: world.defaultDifficulty,
      criticalMargin: world.criticalMargin,
    );

    final node = currentNode;
    var turnSession = session;
    String? nextNodeId;
    if (node is BoundedCorridorNode) {
      final turnsUsed = session.corridorTurnsUsed + 1;
      turnSession = session.copyWith(corridorTurnsUsed: turnsUsed);
      if (node.isBudgetExhausted(turnsUsed)) {
        nextNodeId = node.fallbackExitNodeId;
      }
    }

    await _resolveTurn(
      world: world,
      session: turnSession,
      playerAction: action,
      resolution: resolution,
      curatedEffects: const [],
      nodeContext: _nodeContext(node),
      nextNodeId: nextNodeId,
    );
  }

  /// Taps a curated `StoryChoice` (a button, not free text): resolves its own
  /// check (if any) via `ResolveStoryChoice` — never `world.defaultDifficulty`
  /// — and advances the graph once its outcome (and any extended conflict)
  /// says the scene is actually decided.
  Future<void> chooseStoryChoice(StoryChoice choice) => _chooseOption(choice);

  /// Taps a `StateHubNode` activity: same resolution mechanism as a story
  /// choice, but it never advances `currentNodeId` — an activity only
  /// applies its effects and lets the player keep browsing the hub.
  Future<void> chooseHubActivity(HubActivity activity) => _chooseOption(activity);

  Future<void> _chooseOption(Checkable choice) async {
    final world = _world;
    final session = _session;
    final node = currentNode;
    final character = session?.character;
    if (world == null ||
        session == null ||
        node == null ||
        character == null ||
        _isLoading) {
      return;
    }
    if (!_isAvailable(choice, character)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    final extendedConflict = node is FixedAnchorNode ? node.extendedConflict : null;
    final conflictProgress =
        session.extendedConflictProgress ?? const ExtendedConflictProgress();
    final resolved = _resolveStoryChoice(
      choice: choice,
      character: character,
      extendedConflict: extendedConflict,
      conflictProgress: conflictProgress,
    );

    String? nextNodeId;
    if (resolved.advances && choice is StoryChoice) {
      nextNodeId = resolved.outcome.targetNodeId ?? choice.targetNodeId;
    }

    final turnSession = resolved.advances
        ? session
        : session.copyWith(extendedConflictProgress: resolved.updatedConflictProgress);

    await _resolveTurn(
      world: world,
      session: turnSession,
      playerAction: _labelOf(choice),
      resolution: resolved.actionResolution,
      curatedEffects: resolved.outcome.effects,
      nodeContext: _nodeContext(node),
      nextNodeId: nextNodeId,
      curatedResultText: resolved.outcome.resultText,
    );
  }

  String _labelOf(Checkable choice) => switch (choice) {
        StoryChoice c => c.label,
        HubActivity a => a.label,
        _ => '',
      };

  bool _isAvailable(Checkable choice, Character character) => switch (choice) {
        StoryChoice c => c.isAvailableTo(character),
        HubActivity a => a.isAvailableTo(character),
        _ => true,
      };

  /// Shared tail of every turn, freeform or curated: narrate, validate &
  /// apply deltas (curated ones plus whatever the AI proposes within the
  /// allowed contract), commit the turn, optionally move `currentNodeId` to
  /// [nextNodeId], persist, and refresh the medium-term memory digest.
  Future<void> _resolveTurn({
    required World world,
    required GameSession session,
    required String playerAction,
    required ActionResolution? resolution,
    required List<StateDelta> curatedEffects,
    required _NodeContext nodeContext,
    String? nextNodeId,
    String? curatedResultText,
  }) async {
    try {
      String narration;
      String tone;
      List<String> choiceLabels;
      List<StateDelta> proposedDeltas;

      if (world.aiRuntimeRequired) {
        final response = await _narrator.narrate(
          NarratorRequest(
            world: world,
            character: session.character,
            playerAction: playerAction,
            resolution: resolution,
            recentTurns: _recentTurns(session),
            memoryDigest: _memoryDigestText,
            nodeFixedReveals: nodeContext.fixedReveals,
            nodeForbiddenReveals: nodeContext.forbiddenReveals,
            nodeGoal: nodeContext.goal,
          ),
        );
        narration = response.narration;
        tone = response.tone;
        choiceLabels = [for (final c in response.suggestedChoices) c.label];
        proposedDeltas = [
          for (final delta in response.stateDeltas) ?delta.toStateDelta(),
        ];
      } else {
        // Curated, AI-free world (campaign-bible §25.10): the resolved
        // outcome's own authored text is the turn's narration, interpolated
        // against the character about to receive [curatedEffects]. NEVER
        // calls `NarratorPort` — this world makes zero AI calls, period.
        narration = _interpolate(
          curatedResultText ?? '',
          character: session.character,
          protagonistName: session.character.name,
        );
        tone = world.tone;
        choiceLabels = const [];
        proposedDeltas = const [];
      }

      final beforeLevel = session.character.level;
      final candidateDeltas = [...curatedEffects, ...proposedDeltas];
      final application = _applyDeltas(session.character, candidateDeltas);

      final turn = Turn(
        index: session.turns.length,
        playerAction: playerAction,
        narration: narration,
        tone: tone,
        suggestedChoices: choiceLabels,
      );
      var updatedSession = session.copyWith(
        character: application.character,
        turns: [...session.turns, turn],
      );

      var narrationToShow = narration;
      if (nextNodeId != null) {
        final nextNode = world.storyGraph!.nodeById(nextNodeId);
        updatedSession = updatedSession.copyWith(
          currentNodeId: nextNodeId,
          clearExtendedConflictProgress: true,
          corridorTurnsUsed: nextNode is BoundedCorridorNode ? 0 : updatedSession.corridorTurnsUsed,
        );
        final literal = _literalNarrationOf(nextNode, updatedSession.character);
        if (literal != null) {
          narrationToShow =
              narrationToShow.isEmpty ? literal : '$narrationToShow\n\n$literal';
        }
      }

      _session = updatedSession;
      _narration = narrationToShow;
      _choices = choiceLabels;
      _tone = tone;
      _lastResolution = resolution;
      _lastLevelsGained = application.character.level - beforeLevel;

      // Durably record the turn and the character's new state, if a
      // persistence adapter is configured (Fase 1). Deltas — AI-proposed or
      // curated — are already validated and applied by this point, so
      // what's persisted is authoritative state, never raw AI output.
      final persistence = _persistence;
      final sessionId = session.id;
      if (persistence != null && sessionId != null) {
        await persistence.saveCharacter(sessionId, application.character);
        await persistence.appendTurn(
          sessionId: sessionId,
          turnIndex: turn.index,
          playerAction: playerAction,
          resolution: resolution,
          narration: narration,
          tone: tone,
          suggestedChoices: choiceLabels,
        );
        if (world.storyGraph != null) {
          await persistence.saveGraphPosition(
            sessionId: sessionId,
            currentNodeId: updatedSession.currentNodeId,
            corridorTurnsUsed: updatedSession.corridorTurnsUsed,
            extendedConflictProgress: updatedSession.extendedConflictProgress,
          );
        }
      }

      // Medium-term memory: every _digestEveryNTurns, compress the turns
      // since the last digest into a fresh summary that continues it
      // (CLAUDE.md §6, GDD §5.3), instead of ever sending the full history.
      // A world with `aiRuntimeRequired == false` never calls the narrator,
      // so there is nothing generative to digest either.
      final memoryDigest = _memoryDigest;
      final updatedTurns = _session!.turns;
      if (world.aiRuntimeRequired &&
          memoryDigest != null &&
          updatedTurns.length % _digestEveryNTurns == 0) {
        final sinceLastDigest = updatedTurns.length > _digestEveryNTurns
            ? updatedTurns.sublist(updatedTurns.length - _digestEveryNTurns)
            : updatedTurns;
        final summary = await memoryDigest.summarize(
          turnsToSummarize: sinceLastDigest,
          previousDigest: _memoryDigestText,
        );
        _memoryDigestText = summary;
        if (persistence != null && sessionId != null) {
          await persistence.saveMemoryDigest(
            sessionId: sessionId,
            upToTurn: updatedTurns.length,
            summaryText: summary,
          );
        }
      }
    } catch (e) {
      _error = world.aiRuntimeRequired ? 'El narrador falló: $e' : 'Error al resolver el turno: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<String> _recentTurns(GameSession session) {
    final recent = session.turns.reversed.take(3).toList().reversed;
    return [for (final t in recent) '${t.playerAction} -> ${t.narration}'];
  }
}
