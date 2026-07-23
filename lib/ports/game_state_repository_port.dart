import '../core/engine/action_resolution.dart';
import '../core/state/character.dart';
import '../core/state/game_session.dart';

/// Persists and loads game state (CLAUDE.md §2.1, §7, GDD §8): Postgres is
/// the source of truth, `turns` is an immutable event log, and the current
/// state is its projection. The domain never talks to Supabase directly —
/// only through this port.
abstract class GameStateRepositoryPort {
  /// Returns the player's most recent non-abandoned session for [worldSlug],
  /// including its character and full turn history, or `null` if none exists
  /// yet (a new game should be started).
  Future<GameSession?> loadLatestSession(String worldSlug);

  /// Creates a new session with its starting [character] and returns the
  /// resulting [GameSession] (with its persisted `id` set).
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
  });

  /// Persists the character's current state after a turn.
  Future<void> saveCharacter(String sessionId, Character character);

  /// Appends an immutable turn to the session's event log.
  Future<void> appendTurn({
    required String sessionId,
    required int turnIndex,
    required String playerAction,
    required ActionResolution? resolution,
    required String narration,
    required String tone,
    required List<String> suggestedChoices,
  });

  /// Returns the most recent memory digest text for [sessionId], or `null`
  /// if none has been generated yet (CLAUDE.md §6, GDD §5.3).
  Future<String?> loadLatestMemoryDigest(String sessionId);

  /// Persists a regenerated memory digest, covering turns up to [upToTurn].
  Future<void> saveMemoryDigest({
    required String sessionId,
    required int upToTurn,
    required String summaryText,
  });
}
