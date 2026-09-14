import 'package:aurivo/core/router/app_routes.dart';
import 'package:aurivo/core/router/router.dart';
import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:aurivo/features/authentication/providers/session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit-tests the real `/reset-password` redirect guard against the actual
/// providers: the repository's authoritative recovery authorization and the
/// `isAuthenticatedProvider` seam. Recovery authorization is only ever
/// established through the fake's legitimate lifecycle (no public setter).

/// Exposes a [Ref] so the guard can be called exactly as the router calls it.
final _refProvider = Provider<Ref>((ref) => ref);

ProviderContainer _container({
  required FakeAuthRepository repository,
  required bool authenticated,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      isAuthenticatedProvider.overrideWithValue(authenticated),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _authorizeRecovery(FakeAuthRepository repo) async {
  await repo.sendPasswordResetCode(identifier: 'aya@aurivo.pk');
  await repo.verifyOtp(otp: '123456');
}

void main() {
  group('resetPasswordRedirect', () {
    test('logged-out + unauthorized -> /forgot-password', () {
      final repo = FakeAuthRepository(delay: Duration.zero);
      final ref = _container(
        repository: repo,
        authenticated: false,
      ).read(_refProvider);

      expect(resetPasswordRedirect(ref), AppRoutes.forgotPassword);
    });

    test('authenticated + unauthorized -> /home', () {
      final repo = FakeAuthRepository(delay: Duration.zero);
      final ref = _container(
        repository: repo,
        authenticated: true,
      ).read(_refProvider);

      expect(resetPasswordRedirect(ref), AppRoutes.home);
    });

    test('recovery-authorized -> allowed (no redirect)', () async {
      final repo = FakeAuthRepository(delay: Duration.zero);
      await _authorizeRecovery(repo);
      final ref = _container(
        repository: repo,
        authenticated: false,
      ).read(_refProvider);

      expect(resetPasswordRedirect(ref), isNull);
    });

    test('a new auth flow after authorization causes rejection again', () async {
      final repo = FakeAuthRepository(delay: Duration.zero);
      await _authorizeRecovery(repo);
      final ref = _container(
        repository: repo,
        authenticated: false,
      ).read(_refProvider);
      expect(resetPasswordRedirect(ref), isNull);

      // Beginning a login clears the recovery grant -> reset is rejected.
      await repo.login(
        identifier: 'aya@aurivo.pk',
        password: 'Secret123!',
        rememberMe: false,
      );

      expect(resetPasswordRedirect(ref), AppRoutes.forgotPassword);
    });

    test('never redirects to itself (no self-loop)', () {
      for (final authenticated in [true, false]) {
        final repo = FakeAuthRepository(delay: Duration.zero);
        final ref = _container(
          repository: repo,
          authenticated: authenticated,
        ).read(_refProvider);

        // Targets are /home and /forgot-password, neither of which redirects
        // back to /reset-password, so the guard cannot loop.
        expect(resetPasswordRedirect(ref), isNot(AppRoutes.resetPassword));
      }
    });
  });
}
