import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/domain/auth_repository.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_flow.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_result.dart';
import 'package:aurivo/features/authentication/presentation/otp_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A6 OTP regression coverage — automated only. No real email/OTP is sent:
/// verification runs against fakes ('123456' succeeds, anything else throws).
/// The numeric-email-OTP delivery limitation stays DEFERRED and is out of scope.

/// Records verifyOtp invocations and mirrors the fake's success/failure rule
/// ('123456' succeeds, anything else throws). Resolves on a microtask (no
/// timer) so a single pump applies the result — the delayed fake would need
/// fake time to elapse.
class _SpyAuthRepository extends FakeAuthRepository {
  _SpyAuthRepository() : super(delay: Duration.zero);

  int verifyCount = 0;
  String? lastOtp;

  @override
  Future<AuthResult> verifyOtp({required String otp}) async {
    verifyCount++;
    lastOtp = otp;
    if (otp != '123456') {
      throw const AuthException('Invalid verification code');
    }
    return const AuthResult(message: 'Verification successful');
  }
}

/// verifyOtp that stays in flight until the test completes it, so the
/// loading / disabled window is observable.
class _ControllableAuthRepository extends FakeAuthRepository {
  _ControllableAuthRepository() : super(delay: Duration.zero);

  final Completer<AuthResult> completer = Completer<AuthResult>();
  int verifyCount = 0;

  @override
  Future<AuthResult> verifyOtp({required String otp}) {
    verifyCount++;
    return completer.future;
  }
}

void main() {
  Widget harness({required AuthFlow flow, AuthRepository? repository}) {
    final router = GoRouter(
      initialLocation: AppRoutes.otp,
      routes: [
        GoRoute(path: AppRoutes.otp, builder: (_, _) => OtpPage(flow: flow)),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('HOME_MARKER')),
        ),
        GoRoute(
          path: AppRoutes.resetPassword,
          builder: (_, _) => const Scaffold(body: Text('RESET_MARKER')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          repository ?? _SpyAuthRepository(),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  // Fills the six boxes via the paste path (entering the whole code into the
  // first box) — the reliable way to set the OTP value in a widget test.
  Future<void> enterCode(WidgetTester tester, String code) async {
    await tester.enterText(find.byType(EditableText).first, code);
    await tester.pump();
  }

  // Drains the 60s resend countdown (and any <=60s snackbar) so nothing is
  // left pending at teardown.
  Future<void> drainTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 61));
  }

  testWidgets('subtitle is email-only for both flows', (tester) async {
    for (final flow in AuthFlow.values) {
      await tester.pumpWidget(harness(flow: flow));
      await tester.pump();

      expect(
        find.text('Enter the 6-digit code sent to your email.'),
        findsOneWidget,
      );
      expect(find.textContaining('phone'), findsNothing);

      await drainTimers(tester);
    }
  });

  testWidgets('empty OTP shows the shape error and does not call verify', (
    tester,
  ) async {
    final repo = _SpyAuthRepository();
    await tester.pumpWidget(harness(flow: AuthFlow.signup, repository: repo));
    await tester.pump(); // initState: autofocus + countdown

    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(repo.verifyCount, 0);
    expect(find.text('HOME_MARKER'), findsNothing);

    await drainTimers(tester);
  });

  testWidgets('partial OTP shows the shape error and does not call verify', (
    tester,
  ) async {
    final repo = _SpyAuthRepository();
    await tester.pumpWidget(harness(flow: AuthFlow.signup, repository: repo));
    await tester.pump();

    await enterCode(tester, '123');
    await tester.tap(find.text('Verify'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(repo.verifyCount, 0);
    expect(find.text('HOME_MARKER'), findsNothing);

    await drainTimers(tester);
  });

  testWidgets('signup flow: successful verification navigates to /home', (
    tester,
  ) async {
    final repo = _SpyAuthRepository();
    await tester.pumpWidget(harness(flow: AuthFlow.signup, repository: repo));
    await tester.pump();

    await enterCode(tester, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump(); // verify resolves (success)
    await tester.pump(const Duration(milliseconds: 500)); // route transition

    expect(repo.verifyCount, 1);
    expect(repo.lastOtp, '123456');
    expect(find.text('HOME_MARKER'), findsOneWidget);
    expect(find.text('RESET_MARKER'), findsNothing);

    await drainTimers(tester);
  });

  testWidgets(
    'forgot-password flow: successful verification navigates to /reset-password',
    (tester) async {
      final repo = _SpyAuthRepository();
      await tester.pumpWidget(
        harness(flow: AuthFlow.forgotPassword, repository: repo),
      );
      await tester.pump();

      await enterCode(tester, '123456');
      await tester.tap(find.text('Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(repo.verifyCount, 1);
      expect(find.text('RESET_MARKER'), findsOneWidget);
      expect(find.text('HOME_MARKER'), findsNothing);

      await drainTimers(tester);
    },
  );

  testWidgets(
    'verification failure stays on OTP, shows the error, and keeps the digits',
    (tester) async {
      final repo = _SpyAuthRepository();
      await tester.pumpWidget(harness(flow: AuthFlow.signup, repository: repo));
      await tester.pump();

      await enterCode(tester, '000000'); // fake rejects anything but 123456
      await tester.tap(find.text('Verify'));
      await tester.pump(); // verify throws -> failure state applied
      await tester.pump(const Duration(milliseconds: 300)); // snackbar animates in

      expect(repo.verifyCount, 1);
      // No navigation into the app.
      expect(find.text('HOME_MARKER'), findsNothing);
      expect(find.byType(OtpPage), findsOneWidget);
      // Mapped error surfaced (snackbar).
      expect(find.text('Invalid verification code'), findsOneWidget);
      // Entered digits are preserved so the user can correct them.
      final firstBox = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(firstBox.controller.text, '0');

      await drainTimers(tester);
    },
  );

  testWidgets('a verify in flight disables Verify (no duplicate submission)', (
    tester,
  ) async {
    final repo = _ControllableAuthRepository();
    await tester.pumpWidget(harness(flow: AuthFlow.signup, repository: repo));
    await tester.pump();

    await enterCode(tester, '123456');
    await tester.tap(find.text('Verify'));
    await tester.pump(); // verify called, awaits the completer -> loading

    expect(repo.verifyCount, 1);
    // Verify (the only ElevatedButton) is disabled and shows a spinner, so a
    // second submit is impossible while the first is in flight.
    expect(find.byType(ElevatedButton), findsOneWidget);
    final verifyButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(verifyButton.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Finish the in-flight request so no future/timer is left dangling.
    repo.completer.completeError(
      const AuthException('Invalid verification code'),
    );
    await tester.pump();
    expect(repo.verifyCount, 1);

    await drainTimers(tester);
  });

  group('resend countdown', () {
    testWidgets('resend is disabled during the initial countdown', (
      tester,
    ) async {
      await tester.pumpWidget(harness(flow: AuthFlow.signup));
      await tester.pump(); // starts the 60s countdown

      expect(find.text('Resend available in 60s'), findsOneWidget);
      expect(find.text('Did not receive a code?'), findsNothing);

      await drainTimers(tester);
    });

    testWidgets('resend becomes available after the 60s countdown', (
      tester,
    ) async {
      await tester.pumpWidget(harness(flow: AuthFlow.signup));
      await tester.pump();

      await tester.pump(const Duration(seconds: 61)); // countdown elapses

      expect(find.text('Did not receive a code?'), findsOneWidget);
      final resend = tester.widget<TextButton>(find.byType(TextButton));
      expect(resend.onPressed, isNotNull);
    });
  });
}
