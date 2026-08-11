import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/authentication/providers/session_provider.dart';
import 'features/settings/domain/entities/app_settings.dart';
import 'features/settings/providers/settings_providers.dart';

class AurivoApp extends ConsumerWidget {
  const AurivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auth session listener alive for the app's lifetime so the
    // session stays synchronized with Supabase without rebuilding the app.
    ref.listen<SessionState>(sessionProvider, (_, _) {});

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsProvider).themeMode;

    return MaterialApp.router(
      title: 'AURIVO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _materialThemeMode(themeMode),
      routerConfig: router,
    );
  }

  ThemeMode _materialThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}
