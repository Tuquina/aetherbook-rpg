import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/settings/user_settings.dart';
import '../../ports/settings_port.dart';
import 'settings_mappers.dart';

/// Talks to the `user_settings` table (CLAUDE.md §7 style: one jsonb bucket
/// per account). RLS (`auth.uid() = user_id`) is what actually keeps this
/// private, same as `SupabaseGameStateAdapter` — this adapter never filters
/// by user id itself.
class SupabaseSettingsAdapter implements SettingsPort {
  SupabaseSettingsAdapter(this._client);

  final SupabaseClient _client;

  @override
  Future<UserSettings> loadSettings() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const UserSettings();
    final row = await _client
        .from('user_settings')
        .select('settings')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return const UserSettings();
    return userSettingsFromJson(row['settings'] as Map<String, dynamic>?);
  }

  @override
  Future<void> saveSettings(UserSettings settings) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError(
        'saveSettings requires a signed-in user (AuthPort.signInWithGoogle/'
        'signUpWithPassword/signInWithPassword first)',
      );
    }
    await _client.from('user_settings').upsert(
      {'user_id': userId, 'settings': userSettingsToJson(settings)},
      onConflict: 'user_id',
    );
  }
}
