import '../../core/settings/user_settings.dart';
import '../../ports/settings_port.dart';

/// In-memory fake of [SettingsPort] for tests (CLAUDE.md §9) — never touches
/// Supabase. Records every save so tests can assert on it.
class FakeSettingsAdapter implements SettingsPort {
  FakeSettingsAdapter({UserSettings? seeded}) : _current = seeded ?? const UserSettings();

  UserSettings _current;

  final List<UserSettings> saveSettingsCalls = [];

  @override
  Future<UserSettings> loadSettings() async => _current;

  @override
  Future<void> saveSettings(UserSettings settings) async {
    saveSettingsCalls.add(settings);
    _current = settings;
  }
}
