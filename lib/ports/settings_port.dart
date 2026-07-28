import '../core/settings/user_settings.dart';

/// Persists and loads the current account's [UserSettings] (V2 design
/// prototype §6b, CLAUDE.md §4). One row per account, not per session — kept
/// behind a port so the UI never talks to Supabase directly, same as every
/// other concern in this app.
abstract class SettingsPort {
  /// Returns the current account's settings, or [UserSettings]'s defaults if
  /// none have ever been saved (a brand-new account).
  Future<UserSettings> loadSettings();

  /// Persists the full settings value. Always a full replace — [UserSettings]
  /// is small enough that there's no partial-update case worth optimizing
  /// for.
  Future<void> saveSettings(UserSettings settings);
}
