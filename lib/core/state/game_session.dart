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
  });

  final int index;
  final String playerAction;
  final String narration;
  final String tone;

  /// The choices offered after this turn — kept so a resumed session can
  /// show the same options instead of re-invoking the narrator.
  final List<String> suggestedChoices;
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
