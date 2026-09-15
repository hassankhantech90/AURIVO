import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/theme/colors.dart';
import 'package:aurivo/core/theme/theme.dart';
import 'package:aurivo/features/authentication/presentation/password_updated_page.dart';
import 'package:aurivo/features/authentication/widgets/auth_success_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A8 coverage for the REAL PasswordUpdatedPage (the recovery flow's terminal
/// screen). It is a pure StatelessWidget: no providers, backend, or inputs.

const _subtitle =
    'Your password has been updated successfully. You can now sign in again.';

Widget _harness({ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: AppRoutes.passwordUpdated,
    routes: [
      GoRoute(
        path: AppRoutes.passwordUpdated,
        builder: (_, _) => const PasswordUpdatedPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Text('LOGIN_MARKER')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router, theme: theme);
}

Color? _color(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('renders the success mark, copy, and single action', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.text('Password Updated'), findsOneWidget);
    expect(find.text(_subtitle), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);
    // Real success mark (stable type assertion, not implementation details).
    expect(find.byType(AuthSuccessMark), findsOneWidget);
  });

  testWidgets('is a terminal single-action screen with no inputs', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(EditableText), findsNothing); // no fields
    expect(find.byType(ElevatedButton), findsOneWidget); // one primary action
  });

  testWidgets('Back to Login navigates to /login', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    await tester.tap(find.text('Back to Login'));
    // Bounded pumps (not pumpAndSettle): fire go() and run the route transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Navigation reached /login (the old route may still be mid-transition,
    // so asserting its removal would be brittle — reaching the marker is proof).
    expect(find.text('LOGIN_MARKER'), findsOneWidget);
  });

  testWidgets('dark mode: title and subtitle stay on-light (readable)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(theme: AppTheme.dark));
    await tester.pump();

    // AuthScaffold keeps a light surface in both themes, so its text is on-light.
    expect(_color(tester, 'Password Updated'), AppColors.jetBlack);
    expect(_color(tester, 'Password Updated'), isNot(AppColors.pureWhite));
    expect(_color(tester, _subtitle), AppColors.graphite);
    expect(_color(tester, _subtitle), isNot(AppColors.pureWhite));
    // Primary button label is present; its colour is theme-independent
    // (gold background / jetBlack foreground from the shared button style).
    expect(find.text('Back to Login'), findsOneWidget);
  });
}
