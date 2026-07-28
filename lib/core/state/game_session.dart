import '../narrative/extended_conflict.dart';
import 'character.dart';

/// A single played turn — the immutable `turns` event log (GDD §7.4, §8).
class Turn {
  const Turn({
    required this.index,
    required this.playerAction,
    required this.narration,
    required this.tone,
    this.suggestedChoices = const [],
    this.imageUrl,
  });

  final int index;
  final String playerAction;
  final String narration;
  final String tone;

  /// The choices offered after this turn — kept so a resumed session can
  /// show the same options instead of re-invoking the narrator.
  final List<String> suggestedChoices;

  /// The scene illustration for this turn (GDD §6), if one was generated —
  /// `null` for a turn with no AI narration (`aiRuntimeRequired: false`) or
  /// one where image generation hasn't finished/failed. Arrives *after* the
  /// turn is first persisted (`GameStateRepositoryPort.saveTurnImage`
  /// updates it in place once the image is ready), never blocks the turn.
  final String? imageUrl;
}

/// A play session: the current character plus the turn history. Updated by
/// returning copies, never mutated in place.
class GameSession {
  const GameSession({
    this.id,
    required this.worldSlug,
    required this.character,
    this.turns = const [],
    this.currentNodeId,
    this.corridorTurnsUsed = 0,
    this.extendedConflictProgress,
  });

  /// The persisted session's id (`game_sessions.id`), or `null` for a session
  /// that only exists in memory (no persistence adapter wired yet).
  final String? id;

  final String worldSlug;
  final Character character;
  final List<Turn> turns;

  /// Where the player currently is in the world's `StoryGraph` — `null` for
  /// a freeform world with no graph at all (Fase 0 style), which keeps
  /// working exactly as before.
  final String? currentNodeId;

  /// Free-text turns spent inside the current `BoundedCorridorNode` without
  /// picking one of its authored exits yet — reset to `0` whenever
  /// [currentNodeId] moves to a new corridor.
  final int corridorTurnsUsed;

  /// Progress through the current node's `ExtendedConflict`, if any — reset
  /// to `null` on every node change, populated only while a `FixedAnchorNode`
  /// with an extended conflict is still being resolved.
  final ExtendedConflictProgress? extendedConflictProgress;

  GameSession copyWith({
    String? id,
    Character? character,
    List<Turn>? turns,
    String? currentNodeId,
    int? corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
    bool clearExtendedConflictProgress = false,
  }) {
    return GameSession(
      id: id ?? this.id,
      worldSlug: worldSlug,
      character: character ?? this.character,
      turns: turns ?? this.turns,
      currentNodeId: currentNodeId ?? this.currentNodeId,
      corridorTurnsUsed: corridorTurnsUsed ?? this.corridorTurnsUsed,
      extendedConflictProgress: clearExtendedConflictProgress
          ? null
          : (extendedConflictProgress ?? this.extendedConflictProgress),
    );
  }
}

/// A lightweight listing entry for one of the player's own sessions — no
/// turn history, just enough to render a "your stories" list item and decide
/// whether to resume it (CLAUDE.md Fase 2: the freeform "crea tu propia
/// historia" module allows several sessions per world/genre at once, unlike
/// every other module where at most one active session per world makes
/// sense — so listing needs its own lightweight shape instead of loading a
/// full [GameSession], turns and all, for every entry).
class GameSessionSummary {
  const GameSessionSummary({
    required this.id,
    required this.worldSlug,
    required this.characterName,
    required this.updatedAt,
    this.title,
  });

  final String id;
  final String worldSlug;
  final String characterName;
  final DateTime updatedAt;

  /// The player-chosen title for this story, if they set one when starting
  /// it — `null` for every session created before this existed, and for
  /// every non-freeform module, which never asks for one.
  final String? title;
}

/// One row of `GameStateRepositoryPort.readingStats()` — everything Perfil
/// (V2 design prototype §6a) needs about a single session to compute the
/// tomos/turnos/terminadas/per-world/juramentos display, without loading its
/// full turn history. `status` is `game_sessions.status`
/// (`active`/`completed`/`abandoned`); `vowStatus`/`vowTestedCount` mirror
/// the session's character (`vars['vow_status']`/`meters['vow_tested_count']`,
/// see `core/engine/apply_state_deltas.dart`'s `vowStatus` delta case).
class SessionReadingStat {
  const SessionReadingStat({
    required this.sessionId,
    required this.worldSlug,
    required this.status,
    required this.turnCount,
    this.title,
    this.vowId,
    this.vowStatus,
    this.vowTestedCount = 0,
  });

  final String sessionId;
  final String worldSlug;
  final String status;
  final String? title;
  final int turnCount;
  final String? vowId;
  final String? vowStatus;
  final int vowTestedCount;
}
