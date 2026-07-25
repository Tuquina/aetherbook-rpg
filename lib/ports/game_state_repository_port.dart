import '../core/engine/action_resolution.dart';
import '../core/narrative/extended_conflict.dart';
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

  /// Loads one specific session by id, character and full turn history
  /// included, or `null` if it doesn't exist (or isn't this user's — RLS
  /// handles that transparently, same as every other method here). Unlike
  /// [loadLatestSession] (always "the newest for this world slug"), this
  /// resumes an exact entry — used by the "creá tu propia historia" module's
  /// "tus historias" list, where a player can have several active sessions
  /// for the same world slug at once (CLAUDE.md Fase 2).
  Future<GameSession?> loadSession(String sessionId);

  /// All active sessions across [worldSlugs] for the current user, newest
  /// first, as lightweight summaries (no turn history — see
  /// [GameSessionSummary]). Powers the "tus historias" list for the freeform
  /// module, where — unlike every other module — more than one active
  /// session per world slug is expected and intentional.
  Future<List<GameSessionSummary>> listActiveSessions(List<String> worldSlugs);

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

  /// Fills in a turn's scene image (GDD §6) after the fact — the image
  /// always arrives later than [appendTurn], since generating it never
  /// blocks the turn. A no-op if [turnIndex] doesn't exist for [sessionId]
  /// (shouldn't happen in practice, but nothing to update either way).
  Future<void> saveTurnImage({
    required String sessionId,
    required int turnIndex,
    required String imageUrl,
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

  /// Persists the player's current position in the world's `StoryGraph` —
  /// `currentNodeId`, `corridorTurnsUsed` and `extendedConflictProgress` —
  /// so a curated/hybrid session survives closing the app instead of
  /// restarting at `StoryGraph.startNodeId` on resume (CLAUDE.md §11).
  /// [currentNodeId]/[extendedConflictProgress] `null` clears that column.
  /// A no-op for freeform worlds, which never set [currentNodeId].
  Future<void> saveGraphPosition({
    required String sessionId,
    String? currentNodeId,
    required int corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
  });

  /// Marks [sessionId] as no longer active, so [loadLatestSession] stops
  /// returning it — used when the player explicitly restarts a story
  /// (`GameController.start(..., forceNew: true)`) instead of resuming where
  /// they left off. The turn log itself is left intact, not deleted.
  Future<void> abandonSession(String sessionId);
}
