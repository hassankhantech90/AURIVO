import 'dart:async';

import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/theme/colors.dart';
import 'package:aurivo/core/theme/theme.dart';
import 'package:aurivo/features/authentication/data/auth_failure_mapper.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/domain/entities/auth_result.dart';
import 'package:aurivo/features/authentication/presentation/reset_password_page.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Spies on resetPassword while preserving the production recovery gate
/// (super.resetPassword still throws unless a real recovery verify occurred).
class _SpyAuthRepository extends FakeAuthRepository {
  _SpyAuthRepository() : super(delay: Duration.zero);

  int resetCount = 0;
  Object? resetError; // when set, resetPassword throws this after counting
  Completer<AuthResult>? hang; // when set, resetPassword stays in flight

  @override
  Future<AuthResult> resetPassword({required String password}) {
    resetCount++;
    if (hang != null) return hang!.future;
    if (resetError != null) return Future<AuthResult>.error(resetError!);
    return super.resetPassword(password: password);
  }
}

/// Establishes legitimate recovery authorization via the fake's real lifecycle
/// (no public setter).
Future<void> _authorize(_SpyAuthRepository repo) async {
  await repo.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
  await repo.verifyOtp(otp: '123456');
}

Widget _harness(_SpyAuthRepository repo, {ThemeData? theme}) {
  final router = GoRouter(
    initialLocation: AppRoutes.resetPassword,
    routes: [
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: AppRoutes.passwordUpdated,
        builder: (_, _) => const Scaffold(body: Text('PWD_UPDATED_MARKER')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router, theme: theme),
  );
}

Finder _newPassword() => find.byType(EditableText).at(0);
Finder _confirmPassword() => find.byType(EditableText).at(1);

void main() {
  testWidgets('renders the expected fields and copy', (tester) async {
    await tester.pumpWidget(_harness(_SpyAuthRepository()));
    await tester.pump();

    expect(find.text('Create New Password'), findsOneWidget);
    expect(
      find.text('Choose a strong password to protect your AURIVO account.'),
      findsOneWidget,
    );
    expect(find.text('New Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Update Password'), findsOneWidget);
  });

  testWidgets('empty submit shows required errors and does not call reset', (
    tester,
  ) async {
    final repo = _SpyAuthRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.tap(find.text('Update Password'));
    await tester.pump();

    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Confirm password is required'), findsOneWidget);
    expect(repo.resetCount, 0);
  });

  testWidgets('a weak password shows the strength error and does not call reset',
      (tester) async {
    final repo = _SpyAuthRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(_newPassword(), 'weak');
    await tester.enterText(_confirmPassword(), 'weak');
    await tester.tap(find.text('Update Password'));
    await tester.pump();

    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    expect(repo.resetCount, 0);
  });

  testWidgets('mismatched confirmation blocks submit', (tester) async {
    final repo = _SpyAuthRepository();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(_newPassword(), 'Secret123!');
    await tester.enterText(_confirmPassword(), 'Secret123?');
    await tester.tap(find.text('Update Password'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(repo.resetCount, 0);
  });

  testWidgets('valid matching passwords reset once and navigate to '
      'password-updated', (tester) async {
    final repo = _SpyAuthRepository();
    // runAsync: the fake's zero-delay awaits only resolve on the real event
    // loop, not the widget-test FakeAsync clock.
    await tester.runAsync(() => _authorize(repo)); // legitimate authorization
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(_newPassword(), 'Secret123!');
    await tester.enterText(_confirmPassword(), 'Secret123!');
    await tester.tap(find.text('Update Password'));
    // Advance the fake clock in steps (never pumpAndSettle — the success
    // snackbar would trap it), all under 4s so the snackbar timer stays dormant:
    // resolve the zero-delay reset -> success -> go(), then let the router
    // process the change and finish the destination transition.
    await tester.pump(); // reset begins
    await tester.pump(const Duration(milliseconds: 100)); // reset resolves + go()
    await tester.pump(); // router processes the route change
    await tester.pump(const Duration(milliseconds: 400)); // transition completes

    expect(repo.resetCount, 1);
    expect(find.text('PWD_UPDATED_MARKER'), findsOneWidget);

    // Tear the tree down to cancel the success snackbar's pending timer.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a mapped failure keeps the user on the page with values intact',
      (tester) async {
    final repo = _SpyAuthRepository();
    await tester.runAsync(() => _authorize(repo));
    repo.resetError = const SessionExpiredFailure();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(_newPassword(), 'Secret123!');
    await tester.enterText(_confirmPassword(), 'Secret123!');
    await tester.tap(find.text('Update Password'));
    await tester.pump(); // resetPassword throws -> failure

    expect(repo.resetCount, 1);
    // Stayed on the page, no success navigation.
    expect(find.byType(ResetPasswordPage), findsOneWidget);
    expect(find.text('PWD_UPDATED_MARKER'), findsNothing);
    // Mapped error surfaced.
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
    // Entered values preserved for retry.
    expect(
      tester.widget<EditableText>(_newPassword()).controller.text,
      'Secret123!',
    );

    // Tear the tree down to cancel the error snackbar's pending timer.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an in-flight reset disables Update Password (no duplicate submit)',
      (tester) async {
    final repo = _SpyAuthRepository();
    await tester.runAsync(() => _authorize(repo));
    repo.hang = Completer<AuthResult>();
    await tester.pumpWidget(_harness(repo));
    await tester.pump();

    await tester.enterText(_newPassword(), 'Secret123!');
    await tester.enterText(_confirmPassword(), 'Secret123!');
    await tester.tap(find.text('Update Password'));
    await tester.pump(); // reset called, awaits the completer -> loading

    expect(repo.resetCount, 1);
    expect(find.byType(ElevatedButton), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull); // disabled while loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // A second tap on the disabled button does not trigger another reset.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(repo.resetCount, 1);

    // Tear the tree down; the in-flight (never-completed) request and spinner
    // ticker are disposed with it, leaving nothing pending.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('password visibility toggles work independently', (tester) async {
    await tester.pumpWidget(_harness(_SpyAuthRepository()));
    await tester.pump();

    // Both fields obscured initially.
    expect(tester.widget<EditableText>(_newPassword()).obscureText, isTrue);
    expect(tester.widget<EditableText>(_confirmPassword()).obscureText, isTrue);

    // Toggle only the New Password field's eye.
    await tester.tap(find.byIcon(Icons.visibility_outlined).at(0));
    await tester.pump();

    expect(tester.widget<EditableText>(_newPassword()).obscureText, isFalse);
    expect(tester.widget<EditableText>(_confirmPassword()).obscureText, isTrue);
  });

  testWidgets('dark mode: title and entered text are readable (on-light)', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_SpyAuthRepository(), theme: AppTheme.dark));
    await tester.pump();

    // Title on the light auth surface is jetBlack, not white.
    final titleColor = tester
        .widget<Text>(find.text('Create New Password'))
        .style
        ?.color;
    expect(titleColor, AppColors.jetBlack);

    await tester.enterText(_newPassword(), 'Secret123!');
    await tester.pump();
    final entered = tester.widget<EditableText>(_newPassword()).style.color;
    expect(entered, AppColors.charcoal);
    expect(entered, isNot(AppColors.pureWhite));
  });

  // CHARACTERIZATION of CURRENT submit-only validation. This documents existing
  // behavior and is intentionally the target of the separate submit-aware
  // validation fix (Commit 5), which will change this expectation. It does NOT
  // assert stale validation is the desired permanent UX.
  testWidgets('current behavior: a fixed field keeps its stale error until '
      'resubmit (pending Commit 5)', (tester) async {
    await tester.pumpWidget(_harness(_SpyAuthRepository()));
    await tester.pump();

    await tester.enterText(_newPassword(), 'weak');
    await tester.enterText(_confirmPassword(), 'weak');
    await tester.tap(find.text('Update Password'));
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);

    // Correct the field WITHOUT resubmitting; the stale error still shows today.
    await tester.enterText(_newPassword(), 'Secret123!');
    await tester.pump();
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });
}
