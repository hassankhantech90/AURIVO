import '../entities/app_settings.dart';

/// Contract for persisting device-local app settings. No Supabase / network —
/// this is purely on-device preference storage.
abstract class SettingsRepository {
  /// Loads the persisted settings, falling back to defaults.
  Future<AppSettings> load();

  Future<void> saveThemeMode(AppThemeMode mode);

  Future<void> saveNotificationsEnabled(bool enabled);
}
