// prefer_initializing_formals is disabled here: the fields are private and
// Dart forbids private *named* parameters, so `this._field` initializing
// formals are not usable for this public named-argument constructor.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../core/engine/action_resolution.dart';
import '../core/engine/apply_state_deltas.dart';
import '../core/engine/dice.dart';
import '../core/engine/exp_progression.dart';
import '../core/engine/infer_action_attribute.dart';
import '../core/engine/rank_progression.dart';
import '../core/engine/resolve_player_action.dart';
import '../core/state/character.dart';
import '../core/state/game_session.dart';
import '../core/world/world.dart';
import '../ports/game_state_repository_port.dart';
import '../ports/memory_digest_port.dart';
import '../ports/narrator_port.dart';
import '../ports/world_repository_port.dart';

/// Drives the core gameplay loop (GDD §3), wiring the ports together:
///
///   choose -> resolve mechanics (engine) -> narrate (port) ->
///   validate & apply deltas (engine) -> update state -> notify UI
///
/// It depends only on ports and pure engine use cases, never on a concrete AI
/// provider. The randomness source is injectable so the loop is testable.
///
/// [persistence] is optional: when `null` (Fase 0 default), state lives only
/// in memory for the life of the app, exactly as before. When provided
/// (Fase 1), each turn is also durably recorded in Postgres and a session is
/// resumed on [start] instead of always beginning from the world's seed.
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
        _inferAttribute = const InferActionAttribute();

  final WorldRepositoryPort _worldRepository;
  final NarratorPort _narrator;
  final GameStateRepositoryPort? _persistence;
  final MemoryDigestPort? _memoryDigest;
  final int _digestEveryNTurns;
  final ResolvePlayerAction _resolve;
  final InferActionAttribute _inferAttribute;

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

  /// Loads a world and sets up the opening scene — resumed from a persisted
  /// session if [persistence] is configured and one already exists, or from
  /// the world's seed otherwise.
  Future<void> start(String worldSlug) async {
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
      );

      final persistence = _persistence;
      GameSession session;
      if (persistence != null) {
        final existing = await persistence.loadLatestSession(worldSlug);
        session = existing ??
            await persistence.createSession(
              worldSlug: world.slug,
              character: world.startingCharacter,
            );
      } else {
        session = GameSession(
          worldSlug: world.slug,
          character: world.startingCharacter,
        );
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

  /// Plays one turn for the chosen [action].
  Future<void> choose(String action) async {
    final world = _world;
    final session = _session;
    if (world == null || session == null || _isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. Resolve mechanics deterministically — the engine decides, not the AI.
    // Which attribute a check uses is also decided in code, via keyword
    // matching declared per world (CLAUDE.md §2.2, GDD §4.1) — the AI never
    // picks the attribute, whether the action was typed freely or tapped
    // from a suggested choice.
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

    try {
      // 2. Ask the narrator to NARRATE the already-resolved outcome.
      final response = await _narrator.narrate(
        NarratorRequest(
          world: world,
          character: session.character,
          playerAction: action,
          resolution: resolution,
          recentTurns: _recentTurns(session),
          memoryDigest: _memoryDigestText,
        ),
      );

      // 3. Validate & apply the proposed deltas (AI proposes, engine disposes).
      // `ProposedStateDelta.toStateDelta()` also drops any delta whose
      // declared `operation` the engine doesn't support — see its doc
      // comment. `expected_check`/`node_status`/the free-action classifier
      // aren't consumed yet; that's Fase 8, once real content exists.
      final beforeLevel = session.character.level;
      final candidateDeltas = [
        for (final delta in response.stateDeltas) ?delta.toStateDelta(),
      ];
      final application = _applyDeltas(session.character, candidateDeltas);
      final choiceLabels = [
        for (final choice in response.suggestedChoices) choice.label,
      ];

      // 4. Commit the new state.
      final turn = Turn(
        index: session.turns.length,
        playerAction: action,
        narration: response.narration,
        tone: response.tone,
        suggestedChoices: choiceLabels,
      );
      _session = session.copyWith(
        character: application.character,
        turns: [...session.turns, turn],
      );
      _narration = response.narration;
      _choices = choiceLabels;
      _tone = response.tone;
      _lastResolution = resolution;
      _lastLevelsGained = application.character.level - beforeLevel;

      // 5. Durably record the turn and the character's new state, if a
      // persistence adapter is configured (Fase 1). AI proposed the deltas;
      // by this point the engine already validated and applied them, so
      // what's persisted is authoritative state, never raw AI output.
      final persistence = _persistence;
      final sessionId = session.id;
      if (persistence != null && sessionId != null) {
        await persistence.saveCharacter(sessionId, application.character);
        await persistence.appendTurn(
          sessionId: sessionId,
          turnIndex: turn.index,
          playerAction: action,
          resolution: resolution,
          narration: response.narration,
          tone: response.tone,
          suggestedChoices: choiceLabels,
        );
      }

      // 6. Medium-term memory: every _digestEveryNTurns, compress the turns
      // since the last digest into a fresh summary that continues it
      // (CLAUDE.md §6, GDD §5.3), instead of ever sending the full history.
      final memoryDigest = _memoryDigest;
      final updatedTurns = _session!.turns;
      if (memoryDigest != null &&
          updatedTurns.length % _digestEveryNTurns == 0) {
        final sinceLastDigest =
            updatedTurns.length > _digestEveryNTurns
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
      _error = 'El narrador falló: $e';
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
