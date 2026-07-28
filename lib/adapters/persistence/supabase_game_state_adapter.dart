import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/engine/action_resolution.dart';
import '../../core/narrative/extended_conflict.dart';
import '../../core/state/character.dart';
import '../../core/state/game_session.dart';
import '../../ports/game_state_repository_port.dart';
import 'game_state_mappers.dart';

/// Talks to Postgres via Supabase (CLAUDE.md §7, GDD §7.4, §8). Thin by
/// design: all domain<->row translation lives in the pure, unit-tested
/// functions in `game_state_mappers.dart`; this class only orchestrates the
/// actual queries. RLS (auth.uid() = user_id, enforced in migrations) is what
/// actually keeps sessions private — this adapter relies on it rather than
/// filtering by user_id itself, so a signed-in user only ever sees their own
/// rows regardless of what this code does.
class SupabaseGameStateAdapter implements GameStateRepositoryPort {
  SupabaseGameStateAdapter(this._client);

  final SupabaseClient _client;

  @override
  Future<GameSession?> loadLatestSession(String worldSlug) async {
    final sessionRow = await _client
        .from('game_sessions')
        .select()
        .eq('world_slug', worldSlug)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (sessionRow == null) return null;
    return _loadFullSession(sessionRow);
  }

  @override
  Future<GameSession?> loadSession(String sessionId) async {
    final sessionRow = await _client
        .from('game_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    if (sessionRow == null) return null;
    return _loadFullSession(sessionRow);
  }

  /// Shared tail of [loadLatestSession]/[loadSession] once the
  /// `game_sessions` row itself is in hand: fetches its character and full
  /// turn log and assembles the domain [GameSession].
  Future<GameSession?> _loadFullSession(Map<String, dynamic> sessionRow) async {
    final sessionId = sessionRow['id'] as String;

    final characterRow = await _client
        .from('characters')
        .select()
        .eq('session_id', sessionId)
        .maybeSingle();

    // A session row with no matching character is a partial write — e.g. a
    // prior createSession that inserted the session but then failed before
    // inserting the character (a missing-column error, a dropped
    // connection). Treat it as if no session exists so the caller falls
    // through to createSession and gets a clean one, instead of crashing on
    // every future load of this world.
    if (characterRow == null) return null;

    final turnRows = await _client
        .from('turns')
        .select()
        .eq('session_id', sessionId)
        .order('turn_index');

    return GameSession(
      id: sessionId,
      worldSlug: sessionRow['world_slug'] as String,
      character: characterFromRow(characterRow),
      turns: [for (final row in turnRows) turnFromRow(row)],
      currentNodeId: sessionRow['current_node_id'] as String?,
      corridorTurnsUsed: (sessionRow['corridor_turns_used'] as num?)?.toInt() ?? 0,
      extendedConflictProgress:
          extendedConflictProgressFromRow(sessionRow['extended_conflict_progress']),
    );
  }

  @override
  Future<List<GameSessionSummary>> listActiveSessions(List<String> worldSlugs) async {
    if (worldSlugs.isEmpty) return const [];
    final rows = await _client
        .from('game_sessions')
        .select('id, world_slug, updated_at, title, characters(name)')
        .inFilter('world_slug', worldSlugs)
        .eq('status', 'active')
        .order('updated_at', ascending: false);
    return [for (final row in rows) gameSessionSummaryFromRow(row)];
  }

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
    String? title,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'createSession requires a signed-in user (AuthPort.signInWithGoogle/'
        'signUpWithPassword/signInWithPassword first)',
      );
    }

    final sessionRow = await _client
        .from('game_sessions')
        .insert({
          'user_id': userId,
          'world_slug': worldSlug,
          'campaign_slug': campaignSlug,
          'title': title,
        })
        .select()
        .single();

    final sessionId = sessionRow['id'] as String;

    await _client.from('characters').insert(
          characterToRow(sessionId, character),
        );

    return GameSession(id: sessionId, worldSlug: worldSlug, character: character);
  }

  @override
  Future<void> saveCharacter(String sessionId, Character character) async {
    await _client
        .from('characters')
        .update(characterToRow(sessionId, character))
        .eq('session_id', sessionId);
  }

  @override
  Future<void> appendTurn({
    required String sessionId,
    required int turnIndex,
    required String playerAction,
    required ActionResolution? resolution,
    required String narration,
    required String tone,
    required List<String> suggestedChoices,
  }) async {
    await _client.from('turns').insert(
          turnToRow(
            sessionId: sessionId,
            turnIndex: turnIndex,
            playerAction: playerAction,
            resolution: resolution,
            narration: narration,
            tone: tone,
            suggestedChoices: suggestedChoices,
          ),
        );
  }

  @override
  Future<void> saveTurnImage({
    required String sessionId,
    required int turnIndex,
    required String imageUrl,
  }) async {
    await _client
        .from('turns')
        .update({'image_url': imageUrl})
        .eq('session_id', sessionId)
        .eq('turn_index', turnIndex);
  }

  @override
  Future<void> saveCharacterAvatar({
    required String sessionId,
    required String avatarUrl,
  }) async {
    await _client
        .from('characters')
        .update({'avatar_url': avatarUrl})
        .eq('session_id', sessionId);
  }

  @override
  Future<void> saveGraphPosition({
    required String sessionId,
    String? currentNodeId,
    required int corridorTurnsUsed,
    ExtendedConflictProgress? extendedConflictProgress,
  }) async {
    await _client
        .from('game_sessions')
        .update(graphPositionToRow(
          currentNodeId: currentNodeId,
          corridorTurnsUsed: corridorTurnsUsed,
          extendedConflictProgress: extendedConflictProgress,
        ))
        .eq('id', sessionId);
  }

  @override
  Future<void> abandonSession(String sessionId) async {
    await _client
        .from('game_sessions')
        .update({'status': 'abandoned'})
        .eq('id', sessionId);
  }

  @override
  Future<void> completeSession(String sessionId) async {
    await _client
        .from('game_sessions')
        .update({'status': 'completed'})
        .eq('id', sessionId);
  }

  @override
  Future<List<SessionReadingStat>> readingStats() async {
    final rows = await _client.rpc('reading_stats');
    return [for (final row in rows as List) sessionReadingStatFromRow(row as Map<String, dynamic>)];
  }

  @override
  Future<List<SessionLibraryEntry>> storyLibrary() async {
    final rows = await _client.rpc('story_library');
    return [for (final row in rows as List) sessionLibraryEntryFromRow(row as Map<String, dynamic>)];
  }

  @override
  Future<String?> loadLatestMemoryDigest(String sessionId) async {
    final row = await _client
        .from('memory_digests')
        .select()
        .eq('session_id', sessionId)
        .order('up_to_turn', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : row['summary_text'] as String;
  }

  @override
  Future<void> saveMemoryDigest({
    required String sessionId,
    required int upToTurn,
    required String summaryText,
  }) async {
    await _client.from('memory_digests').upsert(
      {
        'session_id': sessionId,
        'up_to_turn': upToTurn,
        'summary_text': summaryText,
      },
      onConflict: 'session_id,up_to_turn',
    );
  }
}
