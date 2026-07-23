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
  });

  /// The persisted session's id (`game_sessions.id`), or `null` for a session
  /// that only exists in memory (no persistence adapter wired yet).
  final String? id;

  final String worldSlug;
  final Character character;
  final List<Turn> turns;

  GameSession copyWith({String? id, Character? character, List<Turn>? turns}) {
    return GameSession(
      id: id ?? this.id,
      worldSlug: worldSlug,
      character: character ?? this.character,
      turns: turns ?? this.turns,
    );
  }
}
