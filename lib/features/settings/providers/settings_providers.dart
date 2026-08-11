import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/shared_preferences_settings_repository.dart';
import '../domain/entities/app_settings.dart';
import '../domain/repositories/settings_repository.dart';

/// Repository binding for device-local settings.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SharedPreferencesSettingsRepository();
});

/// Current app settings, loaded from local storage on first read and updated
/// as the user changes preferences. Persistence failures are swallowed so the
/// UI stays responsive (settings are non-critical, device-local state).
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) {
    return SettingsController(ref.watch(settingsRepositoryProvider));
  },
);

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._repository) : super(const AppSettings()) {
    _load();
  }

  final SettingsRepository _repository;

  Future<void> _load() async {
    try {
      state = await _repository.load();
    } catch (_) {
      // Keep defaults if local storage is unavailable.
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    if (mode == state.themeMode) return;
    state = state.copyWith(themeMode: mode);
    try {
      await _repository.saveThemeMode(mode);
    } catch (_) {}
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled == state.notificationsEnabled) return;
    state = state.copyWith(notificationsEnabled: enabled);
    try {
      await _repository.saveNotificationsEnabled(enabled);
    } catch (_) {}
  }
}
