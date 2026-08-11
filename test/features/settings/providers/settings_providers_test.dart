import 'package:aurivo/features/settings/domain/entities/app_settings.dart';
import 'package:aurivo/features/settings/domain/repositories/settings_repository.dart';
import 'package:aurivo/features/settings/providers/settings_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.initial = const AppSettings()});
  AppSettings initial;

  AppThemeMode? savedTheme;
  bool? savedNotifications;

  @override
  Future<AppSettings> load() async => initial;

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async => savedTheme = mode;

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async =>
      savedNotifications = enabled;
}

ProviderContainer _container(SettingsRepository repo) {
  final container = ProviderContainer(
    overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('AppThemeMode.fromName maps stored strings', () {
    expect(AppThemeMode.fromName('dark'), AppThemeMode.dark);
    expect(AppThemeMode.fromName('light'), AppThemeMode.light);
    expect(AppThemeMode.fromName('system'), AppThemeMode.system);
    expect(AppThemeMode.fromName(null), AppThemeMode.system);
    expect(AppThemeMode.fromName('garbage'), AppThemeMode.system);
  });

  test('controller loads persisted settings on creation', () async {
    final repo = _FakeSettingsRepository(
      initial: const AppSettings(
        themeMode: AppThemeMode.dark,
        notificationsEnabled: false,
      ),
    );
    final container = _container(repo);

    // Force construction, then let the async load complete.
    container.read(settingsProvider);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(settingsProvider);
    expect(state.themeMode, AppThemeMode.dark);
    expect(state.notificationsEnabled, isFalse);
  });

  test('setThemeMode updates state and persists', () async {
    final repo = _FakeSettingsRepository();
    final container = _container(repo);
    container.read(settingsProvider); // construct + start async load
    await Future<void>.delayed(Duration.zero); // let the load complete

    await container
        .read(settingsProvider.notifier)
        .setThemeMode(AppThemeMode.light);

    expect(container.read(settingsProvider).themeMode, AppThemeMode.light);
    expect(repo.savedTheme, AppThemeMode.light);
  });

  test('setThemeMode is a no-op when unchanged (no persist)', () async {
    final repo = _FakeSettingsRepository();
    final container = _container(repo);
    container.read(settingsProvider); // construct + start async load
    await Future<void>.delayed(Duration.zero); // let the load complete

    await container
        .read(settingsProvider.notifier)
        .setThemeMode(AppThemeMode.system);

    expect(repo.savedTheme, isNull);
  });

  test('setNotificationsEnabled updates state and persists', () async {
    final repo = _FakeSettingsRepository();
    final container = _container(repo);
    container.read(settingsProvider); // construct + start async load
    await Future<void>.delayed(Duration.zero); // let the load complete

    await container
        .read(settingsProvider.notifier)
        .setNotificationsEnabled(false);

    expect(container.read(settingsProvider).notificationsEnabled, isFalse);
    expect(repo.savedNotifications, isFalse);
  });
}
