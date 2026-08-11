import 'package:aurivo/features/settings/domain/entities/app_settings.dart';
import 'package:aurivo/features/settings/domain/repositories/settings_repository.dart';
import 'package:aurivo/features/settings/presentation/settings_page.dart';
import 'package:aurivo/features/settings/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsRepository implements SettingsRepository {
  AppThemeMode? savedTheme;
  bool? savedNotifications;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async => savedTheme = mode;

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async =>
      savedNotifications = enabled;
}

Widget _wrap(SettingsRepository repo) {
  return ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
    child: const MaterialApp(home: SettingsPage()),
  );
}

void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('renders the settings sections', (tester) async {
    _tallViewport(tester);
    await tester.pumpWidget(_wrap(_FakeSettingsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('AURIVO 1.0.0'), findsOneWidget);
    // Session is unauthenticated in tests → sign-in shown, not sign-out.
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('selecting a theme updates the selection and persists', (
    tester,
  ) async {
    _tallViewport(tester);
    final repo = _FakeSettingsRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Default is System → the single check is on that row.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'System default'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(repo.savedTheme, AppThemeMode.dark);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Dark'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget); // exactly one selected
  });

  testWidgets('toggling notifications persists the new value', (tester) async {
    _tallViewport(tester);
    final repo = _FakeSettingsRepository();
    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(repo.savedNotifications, isFalse);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });
}
