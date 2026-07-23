import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/engine/action_resolution.dart';
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

    final sessionId = sessionRow['id'] as String;

    final characterRow = await _client
        .from('characters')
        .select()
        .eq('session_id', sessionId)
        .single();

    final turnRows = await _client
        .from('turns')
        .select()
        .eq('session_id', sessionId)
        .order('turn_index');

    return GameSession(
      id: sessionId,
      worldSlug: worldSlug,
      character: characterFromRow(characterRow),
      turns: [for (final row in turnRows) turnFromRow(row)],
    );
  }

  @override
  Future<GameSession> createSession({
    required String worldSlug,
    String? campaignSlug,
    required Character character,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'createSession requires a signed-in user (call signInAnonymously first)',
      );
    }

    final sessionRow = await _client
        .from('game_sessions')
        .insert({
          'user_id': userId,
          'world_slug': worldSlug,
          'campaign_slug': campaignSlug,
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
}
