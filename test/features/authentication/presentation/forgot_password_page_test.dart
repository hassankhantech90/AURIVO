import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/presentation/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// For the pilot, Forgot Password is a "contact support" screen: self-service
/// reset is deferred (a link reset needs deep-linking; a code reset needs
/// custom SMTP), so the old send-code -> OTP flow was removed.
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

  testWidgets('shows contact-support guidance, not a code form', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.textContaining('contact Pareezay.Hub support'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
    // The old broken send-code -> OTP flow is gone.
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
}
