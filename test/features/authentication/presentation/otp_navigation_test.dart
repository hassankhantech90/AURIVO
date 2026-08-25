import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_flow.dart';
import 'package:aurivo/features/authentication/presentation/otp_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app() {
  final router = GoRouter(
    initialLocation: AppRoutes.otp,
    routes: [
      GoRoute(
        path: AppRoutes.otp,
        builder: (_, _) => const OtpPage(flow: AuthFlow.signup),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        const FakeAuthRepository(delay: Duration.zero),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('resending a code does not navigate into the app', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(); // build + start resend countdown
    await tester.pump(const Duration(seconds: 61)); // countdown finishes

    expect(find.text('Resend OTP'), findsOneWidget);
    await tester.tap(find.text('Resend OTP'));
    await tester.pump(); // resendOtp runs (zero delay)
    await tester.pump(); // success state applied

    // Bug regression: resend previously navigated to home.
    expect(find.text('HOME_MARKER'), findsNothing);
    expect(find.byType(OtpPage), findsOneWidget);

    await tester.pump(const Duration(seconds: 61)); // drain restarted timer
  });
}
