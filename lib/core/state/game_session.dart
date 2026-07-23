import 'character.dart';

/// A single played turn. Kept in memory for Fase 0 (no persistence yet); in
/// later phases this becomes the immutable `turns` event log (GDD §7.4, §8).
class Turn {
  const Turn({
    required this.index,
    required this.playerAction,
    required this.narration,
    required this.tone,
  });

  final int index;
  final String playerAction;
  final String narration;
  final String tone;
}

/// An in-memory play session: the current character plus the turn history.
/// Updated by returning copies, never mutated in place.
class GameSession {
  const GameSession({
    required this.worldSlug,
    required this.character,
    this.turns = const [],
  });

  final String worldSlug;
  final Character character;
  final List<Turn> turns;

  GameSession copyWith({Character? character, List<Turn>? turns}) {
    return GameSession(
      worldSlug: worldSlug,
      character: character ?? this.character,
      turns: turns ?? this.turns,
    );
  }
}
