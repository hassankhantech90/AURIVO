import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/authentication/providers/session_provider.dart';

class AurivoApp extends ConsumerWidget {
  const AurivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the auth session listener alive for the app's lifetime so the
    // session stays synchronized with Supabase without rebuilding the app.
    ref.listen<SessionState>(sessionProvider, (_, _) {});

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AURIVO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
