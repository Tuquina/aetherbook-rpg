// prefer_initializing_formals is disabled here: the fields are private and
// Dart forbids private *named* parameters, so `this._field` initializing
// formals are not usable for this public named-argument constructor.
// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';

import '../core/engine/action_resolution.dart';
import '../core/engine/apply_state_deltas.dart';
import '../core/engine/dice.dart';
import '../core/engine/resolve_player_action.dart';
import '../core/state/character.dart';
import '../core/state/game_session.dart';
import '../core/world/world.dart';
import '../ports/game_state_repository_port.dart';
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
class GameController extends ChangeNotifier {
  GameController({
    required WorldRepositoryPort worldRepository,
    required NarratorPort narrator,
    GameStateRepositoryPort? persistence,
    Dice? dice,
  })  : _worldRepository = worldRepository,
        _narrator = narrator,
        _persistence = persistence,
        _resolve = ResolvePlayerAction(dice ?? RandomDice()),
        _applyDeltas = const ApplyStateDeltas();

  final WorldRepositoryPort _worldRepository;
  final NarratorPort _narrator;
  final GameStateRepositoryPort? _persistence;
  final ResolvePlayerAction _resolve;
  final ApplyStateDeltas _applyDeltas;

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
    final resolution = _resolve(
      attribute: session.character.attribute(world.primaryAttribute),
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
        ),
      );

      // 3. Validate & apply the proposed deltas (AI proposes, engine disposes).
      final beforeLevel = session.character.level;
      final application =
          _applyDeltas(session.character, response.stateDeltas);

      // 4. Commit the new state.
      final turn = Turn(
        index: session.turns.length,
        playerAction: action,
        narration: response.narration,
        tone: response.tone,
        suggestedChoices: response.suggestedChoices,
      );
      _session = session.copyWith(
        character: application.character,
        turns: [...session.turns, turn],
      );
      _narration = response.narration;
      _choices = response.suggestedChoices;
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
          suggestedChoices: response.suggestedChoices,
        );
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
