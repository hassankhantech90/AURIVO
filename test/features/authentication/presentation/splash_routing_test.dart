import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/presentation/splash_page.dart';
import 'package:aurivo/features/authentication/providers/onboarding_provider.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Splash startup routing: onboarding gate + auth-aware Home vs Login.
Widget _app({required bool hasSeenOnboarding, required bool isAuthenticated}) {
  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const Scaffold(body: Text('ONBOARDING_MARKER')),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN_MARKER')),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      hasSeenOnboardingProvider.overrideWithValue(hasSeenOnboarding),
      isAuthenticatedProvider.overrideWithValue(isAuthenticated),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _pumpThroughSplash(WidgetTester tester) async {
  await tester.pump(); // build splash, start animation + navigation timer
  await tester.pump(const Duration(milliseconds: 2600)); // past splashDuration
  await tester.pumpAndSettle(); // complete the route swap
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('fresh install (onboarding not seen) -> onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(hasSeenOnboarding: false, isAuthenticated: false),
    );
    await _pumpThroughSplash(tester);
    expect(find.text('ONBOARDING_MARKER'), findsOneWidget);
    expect(find.text('LOGIN_MARKER'), findsNothing);
    expect(find.text('HOME_MARKER'), findsNothing);
  });

  testWidgets('onboarding complete + logged out -> login', (tester) async {
    await tester.pumpWidget(
      _app(hasSeenOnboarding: true, isAuthenticated: false),
    );
    await _pumpThroughSplash(tester);
    expect(find.text('LOGIN_MARKER'), findsOneWidget);
    expect(find.text('HOME_MARKER'), findsNothing);
    expect(find.text('ONBOARDING_MARKER'), findsNothing);
  });

  testWidgets('onboarding complete + authenticated -> home', (tester) async {
    await tester.pumpWidget(
      _app(hasSeenOnboarding: true, isAuthenticated: true),
    );
    await _pumpThroughSplash(tester);
    expect(find.text('HOME_MARKER'), findsOneWidget);
    expect(find.text('LOGIN_MARKER'), findsNothing);
    expect(find.text('ONBOARDING_MARKER'), findsNothing);
  });

  testWidgets('navigates once (splash replaced, single destination)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(hasSeenOnboarding: true, isAuthenticated: true),
    );
    await _pumpThroughSplash(tester);
    // Replacement navigation: splash gone, exactly one destination shown.
    expect(find.byType(SplashPage), findsNothing);
    expect(find.text('HOME_MARKER'), findsOneWidget);
  });
}
