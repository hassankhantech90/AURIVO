import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/presentation/login_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// F2 regression: Login must NOT enforce signup-strength rules — a non-empty
/// weak password passes client validation and reaches the auth layer (Supabase
/// decides). Signup/Reset keep the strict validator (covered in the validator
/// unit tests).
void main() {
  testWidgets('Login accepts a weak non-empty password (no strength errors)', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.login,
      routes: [
        GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            const FakeAuthRepository(delay: Duration.zero),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    // identifier + password fields (both are EditableTexts).
    await tester.enterText(find.byType(EditableText).first, 'buyer@aurivo.pk');
    await tester.enterText(find.byType(EditableText).at(1), 'weak');
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // No signup-strength errors were raised for the weak password.
    expect(find.textContaining('8 characters'), findsNothing);
    expect(find.textContaining('uppercase'), findsNothing);
    expect(find.textContaining('lowercase'), findsNothing);
    expect(find.textContaining('special character'), findsNothing);
    // Validation passed and the login flow proceeded past the form.
    expect(find.text('HOME_MARKER'), findsOneWidget);
  });
}
