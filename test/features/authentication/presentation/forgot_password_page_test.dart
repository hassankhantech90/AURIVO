import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_result.dart';
import 'package:aurivo/features/authentication/presentation/forgot_password_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Without email codes (default until custom SMTP is live) Forgot Password is
/// a "contact support" screen; with EMAIL_OTP it sends a 6-digit reset code
/// and continues on the OTP screen.
void main() {
  Widget harness() {
    final router = GoRouter(
      initialLocation: AppRoutes.forgotPassword,
      routes: [
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, _) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('LOGIN_MARKER')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('shows contact-support guidance, not a code form', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.textContaining('contact Pareezay.Hub support'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
    // No code form while email codes are off.
    expect(find.text('Send Code'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Back to sign in navigates to login', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN_MARKER'), findsOneWidget);
  });

  testWidgets('with email codes: validates and requests a reset code', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository();
    final router = GoRouter(
      initialLocation: AppRoutes.forgotPassword,
      routes: [
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, _) => const ForgotPasswordPage(useCodes: true),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (_, _) => const Scaffold(body: Text('LOGIN_MARKER')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('Send Code'), findsOneWidget);
    await tester.tap(find.text('Send Code'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(repo.requested, isNull);

    await tester.enterText(find.byType(TextField), 'buyer@example.com');
    await tester.tap(find.text('Send Code'));
    await tester.pump();
    expect(repo.requested, 'buyer@example.com');
  });
}

/// Records the reset request and never resolves (the success path's SnackBar
/// and resend-countdown timers would otherwise stay pending under fake time).
class _RecordingAuthRepository extends FakeAuthRepository {
  String? requested;

  @override
  Future<AuthResult> sendPasswordResetCode({required String identifier}) {
    requested = identifier;
    return Completer<AuthResult>().future;
  }
}
