import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/router/main_shell.dart';
import 'package:aurivo/shared/widgets/navigation/luxury_bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A router that mirrors the app's shape: the five primary destinations sit in
/// a [ShellRoute] behind [MainShell], while a detail route lives on the root
/// navigator (so it must open full-screen, without the bottom nav).
GoRouter _router() {
  Page<void> page(String label) =>
      NoTransitionPage(child: Scaffold(body: Text(label)));
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: AppRoutes.home, pageBuilder: (_, _) => page('HOME')),
          GoRoute(
            path: AppRoutes.explore,
            pageBuilder: (_, _) => page('EXPLORE'),
          ),
          GoRoute(
            path: AppRoutes.wholesale,
            pageBuilder: (_, _) => page('WHOLESALE'),
          ),
          GoRoute(
            path: AppRoutes.orders,
            pageBuilder: (_, _) => page('ORDERS'),
          ),
          GoRoute(
            path: AppRoutes.profile,
            pageBuilder: (_, _) => page('PROFILE'),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.product,
        builder: (_, _) => const Scaffold(body: Text('PRODUCT')),
      ),
    ],
  );
}

int _selectedIndex(WidgetTester tester) => tester
    .widget<LuxuryBottomNavigationBar>(find.byType(LuxuryBottomNavigationBar))
    .currentIndex;

void main() {
  testWidgets('renders the bottom nav with Home selected at start', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    expect(find.byType(LuxuryBottomNavigationBar), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect(_selectedIndex(tester), 0);
  });

  testWidgets('tapping a tab switches destination and selection', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: _router()));
    await tester.pumpAndSettle();

    // The Explore tab is the search icon (index 1).
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE'), findsOneWidget);
    expect(_selectedIndex(tester), 1);
  });

  testWidgets('a pushed sub-location still highlights its owning tab', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    // A filtered Explore (query params) resolves to the /explore path.
    router.go('${AppRoutes.explore}?material=Gold');
    await tester.pumpAndSettle();

    expect(find.text('EXPLORE'), findsOneWidget);
    expect(_selectedIndex(tester), 1);
  });

  testWidgets('a root detail route opens without the bottom nav', (
    tester,
  ) async {
    final router = _router();
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.productPath('abc'));
    await tester.pumpAndSettle();

    expect(find.text('PRODUCT'), findsOneWidget);
    expect(find.byType(LuxuryBottomNavigationBar), findsNothing);
  });

  // Regression: pushing a detail route whose path sits under a tab
  // (/profile/addresses under the /profile tab) must not crash with a
  // duplicate page-key assertion. The shell's dedicated navigator key keeps
  // its tab pages out of the root navigator's page list.
  testWidgets('pushing a detail route under a tab path does not crash', (
    tester,
  ) async {
    final rootKey = GlobalKey<NavigatorState>();
    final shellKey = GlobalKey<NavigatorState>();
    Page<void> page(String label) =>
        NoTransitionPage(child: Scaffold(body: Text(label)));
    final router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: AppRoutes.profile,
      routes: [
        ShellRoute(
          navigatorKey: shellKey,
          builder: (context, state, child) =>
              MainShell(location: state.uri.path, child: child),
          routes: [
            GoRoute(path: AppRoutes.home, pageBuilder: (_, _) => page('HOME')),
            GoRoute(
              path: AppRoutes.profile,
              pageBuilder: (_, _) => page('PROFILE'),
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.addresses, // '/profile/addresses' — shares the prefix
          builder: (_, _) => const Scaffold(body: Text('ADDRESSES')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);

    router.push(AppRoutes.addresses);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('ADDRESSES'), findsOneWidget);
  });
}
