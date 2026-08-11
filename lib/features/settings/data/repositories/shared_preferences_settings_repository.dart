import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// [SettingsRepository] backed by `SharedPreferences` (device-local only).
class SharedPreferencesSettingsRepository implements SettingsRepository {
  static const _themeKey = 'settings.theme_mode';
  static const _notificationsKey = 'settings.notifications_enabled';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    final prefs = await _prefs;
    return AppSettings(
      themeMode: AppThemeMode.fromName(prefs.getString(_themeKey)),
      notificationsEnabled: prefs.getBool(_notificationsKey) ?? true,
    );
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setString(_themeKey, mode.name);
  }

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_notificationsKey, enabled);
  }
}
