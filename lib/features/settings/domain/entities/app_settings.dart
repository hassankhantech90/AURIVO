/// Theme preference persisted locally. Kept Flutter-agnostic in the domain
/// layer; the app root maps it to a Material `ThemeMode`.
enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromName(String? name) {
    switch (name) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }

  String label() {
    switch (this) {
      case AppThemeMode.system:
        return 'System default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }
}

/// Immutable, device-local app settings (no server state).
class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.notificationsEnabled = true,
  });

  final AppThemeMode themeMode;
  final bool notificationsEnabled;

  AppSettings copyWith({AppThemeMode? themeMode, bool? notificationsEnabled}) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
