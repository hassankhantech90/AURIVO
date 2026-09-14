import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/domain/auth_repository.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_result.dart';
import 'package:aurivo/features/authentication/presentation/forgot_password_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A reset request that never resolves — lets us assert a valid email passes
/// validation and is dispatched, without the success path's SnackBar / route
/// / countdown timers that would otherwise stay pending under fake time.
class _HangingAuthRepository extends FakeAuthRepository {
  _HangingAuthRepository();

  @override
  Future<AuthResult> sendPasswordResetCode({required String identifier}) =>
      Completer<AuthResult>().future;
}

/// A5 Finding A: Forgot Password recovery is email-only (Supabase
/// resetPasswordForEmail — there is no SMS path). The field must therefore
/// validate as an email, not accept a Pakistan phone number.
void main() {
  Widget harness({AuthRepository? repository}) {
    final router = GoRouter(
      initialLocation: AppRoutes.forgotPassword,
      routes: [
        GoRoute(
          path: AppRoutes.forgotPassword,
          builder: (_, _) => const ForgotPasswordPage(),
        ),
        // Stub the OTP destination so a successful send can navigate.
        GoRoute(
          path: AppRoutes.otp,
          builder: (_, _) => const Scaffold(body: Text('OTP_MARKER')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          repository ?? FakeAuthRepository(delay: Duration.zero),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> tapSendCode(WidgetTester tester) async {
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows an Email field and Send Code button (no phone copy)', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Send Code'), findsOneWidget);
    // The old email-or-phone label must be gone.
    expect(find.text('Email or Phone'), findsNothing);
  });

  testWidgets('empty field is rejected with the email-required copy', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tapSendCode(tester);

    expect(find.text('Email is required'), findsOneWidget);
    // No navigation occurred — still on the Forgot Password screen.
    expect(find.text('OTP_MARKER'), findsNothing);
  });

  testWidgets('malformed email is rejected', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(EditableText).first, 'abc');
    await tapSendCode(tester);

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('OTP_MARKER'), findsNothing);
  });

  testWidgets('a Pakistan phone number is rejected (email-only recovery)', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.enterText(find.byType(EditableText).first, '03001234567');
    await tapSendCode(tester);

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('OTP_MARKER'), findsNothing);
  });

  testWidgets('a modern-TLD email (test@aurivo.online) is accepted', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(repository: _HangingAuthRepository()),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(EditableText).first,
      'test@aurivo.online',
    );
    await tester.tap(find.text('Send Code'));
    await tester.pump();

    // The email passes validation (no field error) and the request is
    // dispatched — unlike the phone/malformed cases, which are blocked at
    // validation. The hanging repository keeps the request in flight, so no
    // success-path timers are left pending.
    expect(find.text('Enter a valid email address'), findsNothing);
  });

  group('submit-aware validation (Finding B)', () {
    testWidgets('no premature validation before the first submit', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      // Type an invalid value but do NOT submit — nothing should validate yet.
      await tester.enterText(find.byType(EditableText).first, 'abc');
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsNothing);
      expect(find.text('Email is required'), findsNothing);
    });

    testWidgets('stale error clears when the field is corrected (no resubmit)', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await tester.enterText(find.byType(EditableText).first, 'abc');
      await tapSendCode(tester);
      expect(find.text('Enter a valid email address'), findsOneWidget);

      // Correct the field to a valid email and pump — the error must clear on
      // its own, without tapping Send Code again.
      await tester.enterText(
        find.byType(EditableText).first,
        'test@aurivo.online',
      );
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsNothing);
    });

    testWidgets('error updates to the new failure after the first submit', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await tester.enterText(find.byType(EditableText).first, 'abc');
      await tapSendCode(tester);
      expect(find.text('Enter a valid email address'), findsOneWidget);

      // Clear the field — live revalidation should swap the message to the
      // required-field copy without another submit.
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsNothing);
      expect(find.text('Email is required'), findsOneWidget);
    });
  });
}
