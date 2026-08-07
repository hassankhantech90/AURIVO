import 'package:aurivo/features/authentication/data/repositories/fake_auth_repository.dart';
import 'package:aurivo/features/authentication/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          const FakeAuthRepository(delay: Duration.zero),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AuthNotifier', () {
    test('toggles remember me', () {
      final container = createContainer();

      container.read(authProvider.notifier).setRememberMe(true);

      expect(container.read(authProvider).rememberMe, isTrue);
    });

    test('login sets success state', () async {
      final container = createContainer();

      await container
          .read(authProvider.notifier)
          .login(identifier: 'customer@aurivo.pk', password: 'Secret123!');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.success);
      expect(state.message, isNotNull);
    });

    test('invalid OTP sets failure state', () async {
      final container = createContainer();

      await container.read(authProvider.notifier).verifyOtp('000000');

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.failure);
      expect(state.message, contains('Invalid'));
    });
  });
}
